defmodule WikWeb.MemberProfileLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  import Cinder.Refresh

  alias Phoenix.LiveView
  alias Utils.Log
  alias Wik.Access
  alias Wik.Accounts
  alias Wik.Blocks
  alias Wik.Tags
  alias Wik.Tags.Tag
  alias Wik.Tags.Tagging
  alias Wik.Wiki
  alias WikWeb.Components
  alias WikWeb.Components.Block.Types.Markdown
  alias WikWeb.Components.MembershipTagging
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI

  @tagging_sorts %{
    "tag.name" => :asc,
    "interest_level" => :desc,
    "skill_level" => :desc
  }

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(access_grants: [])
     |> assign(available_tags: [])
     |> assign(editable?: false)
     |> assign(membership: nil)
     |> assign(page_tree: nil)
     |> assign(primary_block: nil)
     |> assign(primary_block_editable?: false)
     |> assign(primary_block_editing?: false)
     |> assign(primary_block_form: nil)
     |> assign(selected_tag_slug: nil)
     |> assign(selected_tagging_sort: "interest_level")
     |> assign(subscribed_space_id: nil)
     |> assign(subscribed_target_id: nil)
     |> assign(tagging_count: 0)
     |> assign(tagging_modal: new_tagging_modal())
     |> assign(taggings: [])
     |> assign(taggings_query: nil)}
  end

  @impl true
  def handle_params(%{"username" => username} = params, url, socket) do
    selected_tag_slug = Map.get(params, "tag_slug")

    socket =
      case if(socket.assigns.membership && socket.assigns.membership.username == username,
             do: {:ok, socket},
             else: refresh_profile(socket, username)
           ) do
        {:ok, socket} ->
          socket
          |> assign(:selected_tag_slug, selected_tag_slug)
          |> sync_tagging_modal()

        {:error, :not_found} ->
          socket
          |> put_flash(:error, "Member not found")
          |> push_navigate(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/members")

        {:error, error} ->
          Log.scoped_error(
            socket.assigns.current_scope,
            error,
            "member tagging profile load failed"
          )

          socket
          |> put_flash(:error, "Couldn't load member profile")
          |> push_navigate(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/members")
      end

    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        tagging_form_action: if(assigns.tagging_modal.mode == :edit, do: "Update", else: "Save"),
        tagging_modal_open?: assigns.tagging_modal.mode != nil
      )

    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.space presences={@presences} scope={@current_scope} view="members">
        <:actions :if={@primary_block_editable?}>
          <UI.button_edit_soft
            :if={!@primary_block_editing?}
            class=""
            data-testid="primary-block-edit"
            phx-click="primary_block_edit"
          />
        </:actions>

        <:aside>
          <section class="space-y-3">
            <UI.panel_title>
              Membership type
            </UI.panel_title>

            <span class="badge badge-sm bg-base-300 ml-auto">
              {@membership.type |> Atom.to_string() |> String.capitalize()}
            </span>
          </section>

          <section class="space-y-3">
            <UI.panel_title>
              <.icon name="hero-key-micro" /> Access
            </UI.panel_title>

            <div
              :if={@access_grants == []}
              class="rounded-box border border-dashed border-base-300 bg-base-200/40 px-4 py-6 text-sm opacity-60"
              data-testid="member-access-empty"
            >
              No access grants for this space.
            </div>

            <div
              :if={@access_grants != []}
              class=""
              data-testid="member-access-grants"
            >
              <Components.Membership.Access.grant_card
                :for={grant <- @access_grants}
                grant={grant}
                variant={:profile}
              />
            </div>
          </section>
        </:aside>

        <div
          :if={@membership}
          class={[
            "[&>section]:max-w-[80ch]"
          ]}
          data-testid="member-profile-page"
        >
          <UI.page_head>
            <:prepend>
              <.link
                navigate={~p"/#{@current_scope.tenant.slug}/members"}
                class="leading-none opacity-50 hover:opacity-100"
              >
                Members
              </.link>
              <.icon name="hero-chevron-right-mini" class="opacity-50" />
            </:prepend>

            <UI.page_title>
              <.icon name="hero-user-micro" class="opacity-30 size-5" />
              {@membership.username}
            </UI.page_title>
          </UI.page_head>

          <WikWeb.Components.User.avatar
            membership={@membership}
            size="xl"
            tenant={@current_scope.tenant}
            tooltip?
          />

          <section class="space-y-3">
            <div class="flex justify-end">
              <UI.button_add_topic
                :if={@editable?}
                data-testid="member-tagging-add"
                phx-click="tagging_create_start"
                data-tip="Insert topics"
              />
            </div>

            <MembershipTagging.list
              :if={@tagging_count > 0}
              sort_controls?={@tagging_count >= 3}
              active_sort={@selected_tagging_sort}
              membership={@membership}
              query={@taggings_query}
              scope={@current_scope}
            />
          </section>

          <section class="mt-12" data-testid="primary-block">
            <Markdown.editable
              block={@primary_block}
              cancel="primary_block_cancel"
              editing?={@primary_block_editing?}
              form={@primary_block_form}
              id="primary-block"
              page_tree={@page_tree}
              scope={@current_scope}
              submit="primary_block_submit"
            />
          </section>
        </div>

        <Modal.render
          cancel="tagging_form_cancel"
          cancel_testid="member-tagging-cancel"
          open?={@tagging_modal_open?}
          testid="member-tagging-dialog"
        >
          <MembershipTagging.details
            :if={@tagging_modal.mode == :show and @tagging_modal.tagging}
            editable?={@editable?}
            membership={@membership}
            tagging={@tagging_modal.tagging}
            tenant={@current_scope.tenant}
          />

          <MembershipTagging.form
            :if={@tagging_modal.mode in [:create, :edit] and @tagging_modal.form}
            action_label={@tagging_form_action}
            error={@tagging_modal.error}
            form={@tagging_modal.form}
            mode={@tagging_modal.mode}
            options={@available_tags}
            tag={@tagging_modal.tag}
            membership={@membership}
            tenant={@current_scope.tenant}
          />
        </Modal.render>
      </Layouts.space>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("tagging_sort", %{"sort" => sort}, socket)
      when is_map_key(@tagging_sorts, sort) do
    LiveView.send_update(Cinder.LiveComponent,
      id: "member-taggings",
      sort_by: [{sort, Map.fetch!(@tagging_sorts, sort)}],
      current_page: 1,
      after_keyset: nil,
      before_keyset: nil,
      user_has_interacted: true
    )

    {:noreply, assign(socket, :selected_tagging_sort, sort)}
  end

  def handle_event("tagging_sort", _params, socket), do: {:noreply, socket}

  def handle_event(
        "primary_block_edit",
        _params,
        %{assigns: %{primary_block_editable?: false}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("primary_block_edit", _params, socket) do
    scope = socket.assigns.current_scope

    case Accounts.get_or_create_primary_block(socket.assigns.membership, scope: scope) do
      {:ok, _membership, block} ->
        {:noreply,
         socket
         |> assign_primary_block(block)
         |> assign(:primary_block_editing?, true)
         |> assign_primary_block_form(block)}

      {:error, error} ->
        Log.scoped_error(scope, error, "member primary block creation failed")

        {:noreply,
         socket
         |> put_flash(:error, "Couldn't start editing primary block")}
    end
  end

  def handle_event("primary_block_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:primary_block_editing?, false)
     |> assign(:primary_block_form, nil)}
  end

  def handle_event(
        "primary_block_submit",
        _params,
        %{assigns: %{primary_block_editable?: false}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("primary_block_submit", %{"block" => params}, socket) do
    scope = socket.assigns.current_scope

    case Accounts.update_primary_block(socket.assigns.membership, params, scope: scope) do
      {:ok, block} ->
        {:noreply,
         socket
         |> assign_primary_block(block)
         |> assign(:primary_block_editing?, false)
         |> assign(:primary_block_form, nil)}

      {:error, error} ->
        Log.scoped_error(scope, error, "member primary block update failed")

        {:noreply,
         socket
         |> put_flash(:error, "Couldn't update primary block")
         |> assign_primary_block_form(socket.assigns.primary_block, params)}
    end
  end

  def handle_event("tagging_create_start", _params, socket) do
    {:noreply,
     assign(socket, :tagging_modal, new_tagging_modal(:create, form: init_tagging_form(nil)))}
  end

  def handle_event("tagging_edit_start", %{"tag_id" => tag_id}, socket) do
    tagging = Enum.find(socket.assigns.taggings, &(&1.tag_id == tag_id))

    {:noreply,
     assign(
       socket,
       :tagging_modal,
       new_tagging_modal(:edit,
         form: init_tagging_form(tagging),
         tag: tagging && tagging.tag,
         tagging: tagging
       )
     )}
  end

  def handle_event("tagging_form_cancel", _params, socket) do
    {:noreply, cancel_tagging_modal(socket)}
  end

  def handle_event("tagging_validate", %{"form" => params}, socket) do
    {:noreply,
     update(socket, :tagging_modal, fn modal ->
       %{modal | form: to_form(normalize_tagging_form(params), as: :form), error: nil}
     end)}
  end

  def handle_event("tagging_submit", %{"form" => params}, socket) do
    scope = socket.assigns.current_scope
    membership = socket.assigns.membership

    socket =
      case parse_tagging_params(params) do
        {:ok, tagging_params} ->
          case save_tagging_entry(
                 membership,
                 tagging_params.tag_id,
                 tagging_params,
                 scope
               ) do
            :ok ->
              handle_saved_tagging(socket)

            {:error, error} ->
              Log.scoped_error(scope, error, "membership tagging submit failed")

              assign_tagging_form_error(socket, params, "Couldn't save that tagging.")
          end

        {:error, message} ->
          assign_tagging_form_error(socket, params, message)
      end

    {:noreply, socket}
  end

  def handle_event("tagging_remove", %{"tag_id" => tag_id}, socket) do
    scope = socket.assigns.current_scope
    membership = socket.assigns.membership

    socket =
      case remove_tagging_entry(membership, tag_id, scope) do
        :ok ->
          socket
          |> close_tagging_form()
          |> refresh_taggings()
          |> maybe_patch_to_profile()

        {:error, error} ->
          Log.scoped_error(scope, error, "membership tagging remove failed")
          socket
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: topic}, socket) do
    space_id = socket.assigns.current_scope.tenant.id
    membership_id = socket.assigns.membership && socket.assigns.membership.id

    watched_topics =
      [Tag.space_pub_sub_topic(space_id)] ++
        if membership_id,
          do: [Tagging.target_pub_sub_topic("membership", membership_id)],
          else: []

    if topic in watched_topics and socket.assigns.membership do
      {:noreply, refresh_taggings(socket)}
    else
      {:noreply, socket}
    end
  end

  defp refresh_profile(socket, username) do
    scope = socket.assigns.current_scope

    case Accounts.get_membership_by_username(scope.tenant, username) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, membership} ->
        with {:ok, taggings} <- Tags.list_taggings(membership, scope: scope),
             {:ok, available_tags} <- Tags.list_space_tags(scope),
             {:ok, access_grants} <-
               Access.list_space_user_grants(membership.space_id, membership.user_id) do
          page_tree = Wiki.load_page_tree(scope)
          primary_block = load_primary_block(membership, scope)

          if connected?(socket) and socket.assigns.subscribed_space_id != scope.tenant.id do
            :ok = WikWeb.Endpoint.subscribe(Tag.space_pub_sub_topic(scope.tenant.id))
          end

          if connected?(socket) and socket.assigns.subscribed_target_id != membership.id do
            :ok =
              WikWeb.Endpoint.subscribe(Tagging.target_pub_sub_topic("membership", membership.id))
          end

          {:ok,
           assign_profile_state(
             socket,
             membership,
             taggings,
             available_tags,
             access_grants,
             page_tree,
             primary_block
           )}
        else
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp try_reload_profile(socket) do
    case refresh_profile(socket, socket.assigns.membership.username) do
      {:ok, socket} -> socket
      {:error, _error} -> socket
    end
  end

  defp assign_profile_state(
         socket,
         membership,
         taggings,
         available_tags,
         access_grants,
         page_tree,
         primary_block
       ) do
    current_membership =
      socket.assigns.tenant_context && socket.assigns.tenant_context.current_membership

    profile_state =
      profile_state(membership, taggings, current_membership, socket.assigns.current_scope.actor)

    socket
    |> assign(:access_grants, access_grants)
    |> assign(:available_tags, available_tags)
    |> assign(:primary_block_editing?, false)
    |> assign(:membership, membership)
    |> assign(:primary_block_form, nil)
    |> assign(:page_tree, page_tree)
    |> assign(:taggings, taggings)
    |> assign(:taggings_query, Tags.taggings_query(membership))
    |> assign(profile_state)
    |> assign_primary_block(primary_block)
  end

  defp assign_primary_block(socket, nil) do
    assign(socket, :primary_block, nil)
  end

  defp assign_primary_block(socket, block) do
    assign(socket, :primary_block, block)
  end

  defp assign_primary_block_form(socket, block, params \\ %{}) do
    form =
      block
      |> Blocks.block_to_form_params(params, socket.assigns.page_tree)
      |> to_form(as: :block)

    assign(socket, :primary_block_form, form)
  end

  defp load_primary_block(membership, scope) do
    case Accounts.get_primary_block(membership, scope: scope) do
      {:ok, block} ->
        block

      {:error, error} ->
        Log.scoped_error(scope, error, "member primary block load failed")
        nil
    end
  end

  defp init_tagging_form(nil) do
    to_form(
      %{"tag_id" => "", "interest_level" => "0", "skill_level" => "0", "description" => ""},
      as: :form
    )
  end

  defp init_tagging_form(%Tagging{} = tagging) do
    to_form(
      %{
        "tag_id" => tagging.tag_id,
        "interest_level" => to_string(dimension_level(tagging, "interest") || 0),
        "skill_level" => to_string(dimension_level(tagging, "skill") || 0),
        "description" => tagging.description || ""
      },
      as: :form
    )
  end

  defp close_tagging_form(socket) do
    assign(socket, :tagging_modal, new_tagging_modal())
  end

  defp cancel_tagging_modal(%{assigns: %{selected_tag_slug: tag_slug}} = socket)
       when is_binary(tag_slug) and tag_slug != "" do
    socket
    |> close_tagging_form()
    |> push_patch(
      to: member_profile_path(socket.assigns.current_scope, socket.assigns.membership)
    )
  end

  defp cancel_tagging_modal(socket), do: close_tagging_form(socket)

  defp normalize_tagging_form(params) do
    %{
      "tag_id" => Map.get(params, "tag_id", ""),
      "interest_level" => Map.get(params, "interest_level", "0"),
      "skill_level" => Map.get(params, "skill_level", "0"),
      "description" => Map.get(params, "description", "")
    }
  end

  defp parse_tagging_params(params) do
    with tag_id when is_binary(tag_id) and tag_id != "" <- Map.get(params, "tag_id"),
         {:ok, interest_level} <- parse_level(params, "interest_level"),
         {:ok, skill_level} <- parse_level(params, "skill_level") do
      {:ok,
       %{
         description: Map.get(params, "description", ""),
         interest_level: interest_level,
         skill_level: skill_level,
         tag_id: tag_id
       }}
    else
      _ -> {:error, "Select a tag and enter valid levels."}
    end
  end

  defp save_tagging_entry(membership, tag_id, tagging_params, scope) do
    attrs = %{
      description: tagging_params.description,
      dimensions: %{
        "interest" => tagging_params.interest_level,
        "skill" => tagging_params.skill_level
      }
    }

    if empty_dimensions?(attrs.dimensions) do
      remove_tagging_entry(membership, tag_id, scope)
    else
      case Tags.upsert_tagging(membership, membership, tag_id, attrs, scope: scope) do
        {:ok, _tagging} -> :ok
        {:error, error} -> {:error, error}
      end
    end
  end

  defp remove_tagging_entry(membership, tag_id, scope) do
    case Tags.remove_tagging(membership, membership, tag_id, scope: scope) do
      {:ok, _tagging} -> :ok
      {:error, :not_found} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp assign_tagging_form_error(socket, params, message) do
    update(socket, :tagging_modal, fn modal ->
      %{modal | form: to_form(normalize_tagging_form(params), as: :form), error: message}
    end)
  end

  defp profile_state(membership, taggings, current_membership, actor) do
    %{
      primary_block_editable?: !!(current_membership && current_membership.id == membership.id),
      editable?:
        (current_membership && current_membership.id == membership.id) ||
          actor_superadmin?(actor),
      subscribed_space_id: membership.space_id,
      subscribed_target_id: membership.id,
      tagging_count: length(taggings)
    }
  end

  defp new_tagging_modal(mode \\ nil, attrs \\ []) do
    %{
      error: Keyword.get(attrs, :error),
      form: Keyword.get(attrs, :form),
      mode: mode,
      tag: Keyword.get(attrs, :tag),
      tagging: Keyword.get(attrs, :tagging)
    }
  end

  defp empty_dimensions?(dimensions) do
    dimensions
    |> Enum.reject(fn {_key, value} -> value == 0 end)
    |> Enum.empty?()
  end

  defp dimension_level(%Tagging{dimensions: dimensions}, key) when is_map(dimensions) do
    Map.get(dimensions, key)
  end

  defp dimension_level(_tagging, _key), do: nil

  defp actor_superadmin?(%{role: :superadmin}), do: true
  defp actor_superadmin?(_actor), do: false

  defp parse_level(params, key) do
    case Integer.parse(Map.get(params, key, "0")) do
      {level, ""} -> {:ok, level}
      _ -> :error
    end
  end

  defp sync_tagging_modal(%{assigns: %{selected_tag_slug: tag_slug}} = socket)
       when is_binary(tag_slug) and tag_slug != "" do
    case Enum.find(socket.assigns.taggings, &(&1.tag && &1.tag.slug == tag_slug)) do
      %Tagging{} = tagging ->
        assign(
          socket,
          :tagging_modal,
          new_tagging_modal(:show,
            tag: tagging.tag,
            tagging: tagging
          )
        )

      nil ->
        socket
        |> put_flash(:error, "Tagging not found")
        |> push_patch(
          to: member_profile_path(socket.assigns.current_scope, socket.assigns.membership)
        )
    end
  end

  defp sync_tagging_modal(%{assigns: %{selected_tag_slug: tag_slug, membership: nil}} = socket)
       when is_binary(tag_slug) and tag_slug != "" do
    close_tagging_form(socket)
  end

  defp sync_tagging_modal(socket) do
    case socket.assigns.tagging_modal.mode do
      mode when mode in [:show, :edit] -> close_tagging_form(socket)
      _mode -> socket
    end
  end

  defp handle_saved_tagging(%{assigns: %{selected_tag_slug: tag_slug}} = socket)
       when is_binary(tag_slug) and tag_slug != "" do
    socket
    |> refresh_taggings()
    |> sync_tagging_modal()
  end

  defp handle_saved_tagging(socket) do
    socket
    |> close_tagging_form()
    |> refresh_taggings()
  end

  defp maybe_patch_to_profile(%{assigns: %{selected_tag_slug: tag_slug}} = socket)
       when is_binary(tag_slug) and tag_slug != "" do
    push_patch(socket,
      to: member_profile_path(socket.assigns.current_scope, socket.assigns.membership)
    )
  end

  defp maybe_patch_to_profile(socket), do: socket

  defp refresh_taggings(socket) do
    socket
    |> try_reload_profile()
    |> refresh_table("member-taggings")
  end

  defp member_profile_path(scope, membership) do
    ~p"/#{scope.tenant.slug}/wiki/members/#{membership.username}"
  end
end
