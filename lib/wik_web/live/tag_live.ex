defmodule WikWeb.TagLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Phoenix.LiveView
  alias Utils.Log
  alias Wik.Accounts
  alias Wik.Blocks
  alias Wik.Tags
  alias Wik.Tags.Dimensions
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag
  alias Wik.Wiki
  alias WikWeb.Components
  alias WikWeb.Components.Block.Types.Markdown
  alias WikWeb.Components.DimensionsList
  alias WikWeb.Components.MembershipTagging
  alias WikWeb.Components.Modal
  alias WikWeb.Components.Tag, as: TagComponent
  alias WikWeb.Components.UI

  @member_tagging_sorts %{
    "target_membership.username" => :asc_nils_last,
    "interest_level" => :desc,
    "skill_level" => :desc
  }

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    editable? = Ash.can?({Tag, :create}, socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(current_member_tagged?: false)
     |> assign(editable?: editable?)
     |> assign(editing?: false)
     |> assign(page_tree: nil)
     |> assign(primary_block: nil)
     |> assign(primary_block_author_membership: nil)
     |> assign(primary_block_editing?: false)
     |> assign(primary_block_form: nil)
     |> assign(primary_block_version_text: nil)
     |> assign(primary_block_version: nil)
     |> assign(primary_block_version_count: 0)
     |> assign(selected_member_tagging_sort: "interest_level")
     |> assign(show_descendants?: true)
     |> assign(tag: nil)
     |> assign(tag_page_taggings: [])
     |> assign(tag_form: nil)
     |> assign(tag_graph: nil)
     |> assign(tagging_modal: new_tagging_modal())
     |> assign(tagging_count: 0)
     |> assign(taggings_query: nil)}
  end

  @impl true
  def handle_params(%{"tag_slug" => tag_slug}, url, socket) do
    socket =
      case Tags.get_tag_by_slug(tag_slug, scope: socket.assigns.current_scope) do
        {:ok, tag} when not is_nil(tag) ->
          scope = socket.assigns.current_scope
          tag_graph = Tags.load_tag_graph(socket.assigns.current_scope)
          page_tree = Wiki.load_page_tree(scope)
          primary_block = load_primary_block(tag, scope)

          socket
          |> assign(:tag, tag)
          |> assign(:primary_block_editing?, false)
          |> assign(:page_tree, page_tree)
          |> assign(:primary_block_form, nil)
          |> assign_primary_block(primary_block)
          |> assign_tag_graph_state(tag_graph, tag)
          |> assign(:taggings_query, Tags.tag_taggings_query(tag))
          |> assign(:show_descendants?, GraphQueries.children_for(tag_graph, tag) != [])
          |> assign_current_member_tagging(tag)
          |> maybe_sync_tag_form()

        {:ok, nil} ->
          socket
          |> put_flash(:error, "Tag not found")
          |> push_navigate(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/topics")

        {:error, error} ->
          Log.scoped_error(socket.assigns.current_scope, error, "tag page load failed")

          socket
          |> put_flash(:error, "Couldn't load tag")
          |> push_navigate(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/topics")
      end

    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_event("member_tagging_sort", %{"sort" => sort}, socket)
      when is_map_key(@member_tagging_sorts, sort) do
    LiveView.send_update(Cinder.LiveComponent,
      id: "tag-member-taggings",
      sort_by: [{sort, Map.fetch!(@member_tagging_sorts, sort)}],
      current_page: 1,
      after_keyset: nil,
      before_keyset: nil,
      user_has_interacted: true
    )

    {:noreply, assign(socket, :selected_member_tagging_sort, sort)}
  end

  def handle_event("member_tagging_sort", _params, socket), do: {:noreply, socket}

  def handle_event("toggle_edit_mode", _params, socket) do
    socket = assign(socket, editing?: !socket.assigns.editing?)
    socket = if socket.assigns.editing?, do: open_tag_form(socket), else: close_tag_form(socket)
    {:noreply, socket}
  end

  def handle_event("tag_validate", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, :tag_form, Form.validate(socket.assigns.tag_form, tag_params(params)))}
  end

  def handle_event("tag_submit", %{"form" => params}, socket) do
    case Form.submit(socket.assigns.tag_form, params: tag_params(params)) do
      {:ok, %Tag{} = tag} ->
        {:noreply,
         socket
         |> assign(:tag, tag)
         |> close_tag_form()
         |> push_patch(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/topics/#{tag.slug}")}

      {:error, form} ->
        {:noreply, assign(socket, :tag_form, form)}
    end
  end

  def handle_event("primary_block_edit", _params, socket) do
    scope = socket.assigns.current_scope

    case Tags.get_or_create_primary_block(socket.assigns.tag, scope: scope) do
      {:ok, %Tag{} = tag, block} ->
        {:noreply,
         socket
         |> assign(:tag, tag)
         |> assign_primary_block(block)
         |> assign(:primary_block_editing?, true)
         |> assign_primary_block_form(block)}

      {:error, error} ->
        Log.scoped_error(scope, error, "tag primary block creation failed")

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

  def handle_event("primary_block_submit", %{"block" => params}, socket) do
    scope = socket.assigns.current_scope

    case Tags.update_primary_block(socket.assigns.tag, params, scope: scope) do
      {:ok, block} ->
        {:noreply,
         socket
         |> assign_primary_block(block)
         |> assign(:primary_block_editing?, false)
         |> assign(:primary_block_form, nil)}

      {:error, error} ->
        Log.scoped_error(scope, error, "tag primary block update failed")

        {:noreply,
         socket
         |> put_flash(:error, "Couldn't update primary block")
         |> assign_primary_block_form(socket.assigns.primary_block, params)}
    end
  end

  def handle_event("primary_block_history_navigate", %{"direction" => direction}, socket)
      when direction in ["prev", "next"] do
    block = socket.assigns.primary_block
    version = socket.assigns.primary_block_version
    scope = socket.assigns.current_scope

    result =
      case {direction, block, version} do
        {"prev", block, version} when not is_nil(block) and not is_nil(version) ->
          Blocks.load_version_prev(block, version, scope: scope)

        {"next", block, version} when not is_nil(block) and not is_nil(version) ->
          Blocks.load_version_next(block, version, scope: scope)

        _other ->
          {:ok, nil}
      end

    case result do
      {:ok, nil} ->
        {:noreply, socket}

      {:ok, version} ->
        {:noreply, assign_primary_block_selected_version(socket, block, version, scope)}

      {:error, error} ->
        Log.scoped_error(scope, error, "tag primary block history navigation failed")
        {:noreply, socket}
    end
  end

  def handle_event("tagging_create_start", _params, socket) do
    {:noreply,
     assign(
       socket,
       :tagging_modal,
       new_tagging_modal(:create, form: init_tagging_form(socket.assigns.tag))
     )}
  end

  def handle_event("tagging_form_cancel", _params, socket) do
    {:noreply, close_tagging_form(socket)}
  end

  def handle_event("tagging_validate", %{"form" => params}, socket) do
    {:noreply,
     update(socket, :tagging_modal, fn modal ->
       %{modal | form: to_form(normalize_tagging_form(params), as: :form), error: nil}
     end)}
  end

  def handle_event("tagging_submit", %{"form" => params}, socket) do
    socket =
      case {socket.assigns.tenant_context.current_membership, parse_tagging_params(params)} do
        {nil, _result} ->
          assign_tagging_form_error(socket, params, "Join this space before adding topics.")

        {_membership, {:error, message}} ->
          assign_tagging_form_error(socket, params, message)

        {membership, {:ok, tagging_params}} ->
          save_tagging_entry(membership, tagging_params, socket)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        tagging_modal_open?: assigns.tagging_modal.mode != nil
      )

    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.space presences={@presences} scope={@current_scope} view="tags">
        <:actions :if={@editable?}>
          <%= if @editing? do %>
          <% else %>
            <button
              :if={@editable? and !@primary_block_editing?}
              phx-click="toggle_edit_mode"
              data-testid="tag-edit-mode-toggle"
              class={[
                "btn btn-xs btn-circle btn-accent btn-ghost",
                "text-accent hover:text-base-content",
                "opacity-60 hover:opacity-100"
              ]}
            >
              <.icon name="hero-cog-6-tooth-micro" class="size-3.5" />
            </button>

            <UI.button_edit_soft
              :if={@editable? and !@primary_block_editing?}
              class=""
              data-testid="primary-block-edit"
              phx-click="primary_block_edit"
            />
          <% end %>
        </:actions>

        <:aside :if={not @editing?}>
          <section :if={@show_descendants?}>
            <TagComponent.descendants
              graph={@tag_graph}
              scope={@current_scope}
              tag={@tag}
            />
          </section>

          <section :if={@tag_page_taggings != []} data-testid="tag-pages">
            <% relevancy_dimension = Dimensions.get!("page", "relevancy") %>

            <UI.panel_title>
              <div>Pages</div>
            </UI.panel_title>

            <DimensionsList.render
              dimension={relevancy_dimension}
              item_id={:id}
              items={@tag_page_taggings}
              level={:relevancy_level}
              list_testid="tag-page-list"
              navigate={&~p"/#{@current_scope.tenant.slug}/wiki/#{&1.path_segments}"}
              testid_prefix="tag-page"
            >
              <:title :let={page}>
                <div class="text-sm truncate">{page.title}</div>
              </:title>
            </DimensionsList.render>
          </section>

          <section>
            <div class="flex justify-between items-baseline">
              <UI.panel_title>
                <div>History</div>
              </UI.panel_title>

              <div>
                <button
                  type="button"
                  data-testid="primary-block-history-prev"
                  phx-click="primary_block_history_navigate"
                  phx-value-direction="prev"
                  class={[
                    "hover:opacity-100 transition-opacity",
                    "cursor-pointer",
                    primary_block_prev_disabled?(@primary_block_version) &&
                      "pointer-events-none opacity-20",
                    !primary_block_prev_disabled?(@primary_block_version) &&
                      "opacity-50 hover:opacity-100"
                  ]}
                >
                  <span class="sr-only">prev</span>
                  <.icon name="hero-chevron-left-micro" />
                </button>

                <button
                  type="button"
                  data-testid="primary-block-history-next"
                  phx-click="primary_block_history_navigate"
                  phx-value-direction="next"
                  class={[
                    "transition-opacity",
                    "cursor-pointer",
                    primary_block_next_disabled?(
                      @primary_block_version,
                      @primary_block_version_count
                    ) &&
                      "pointer-events-none opacity-20",
                    !primary_block_next_disabled?(
                      @primary_block_version,
                      @primary_block_version_count
                    ) &&
                      "opacity-50 hover:opacity-100"
                  ]}
                >
                  <span class="sr-only">next</span>
                  <.icon name="hero-chevron-right-micro" />
                </button>

                <div
                  :if={@primary_block != nil}
                  class="badge badge-sm badge-neutral"
                >
                  <span class="opacity-60">v.</span>
                  <span data-testid="primary-block-version" class="text-xs opacity-60">
                    {primary_block_version_label(
                      @primary_block_version,
                      @primary_block_version_count
                    )}
                  </span>
                </div>
              </div>
            </div>

            <div
              :if={@primary_block == nil}
              class="text-sm opacity-60"
              data-testid="primary-block-history-empty"
            >
              No content yet.
            </div>

            <div
              :if={@primary_block != nil}
              class="text-xs flex gap-2 justify-between"
              data-testid="primary-block-history"
            >
              <div data-testid="primary-block-author">
                <Components.User.identity
                  :if={@primary_block_author_membership}
                  avatar_size="xs"
                  class="gap-2"
                  link?
                  membership={@primary_block_author_membership}
                />
                <span :if={!@primary_block_author_membership} class="opacity-60">Unknown</span>
              </div>

              <div data-testid="primary-block-updated-at">
                <Components.Time.relative_and_precise
                  datetime={primary_block_timestamp(@primary_block_version, @primary_block)}
                  direction="left"
                  ago?
                />
              </div>
            </div>
          </section>

          <%!-- <section> --%>
          <%!--   <TagComponent.children graph={@tag_graph} scope={@current_scope} tag={@tag} /> --%>
          <%!-- </section> --%>
        </:aside>

        <div :if={@tag} class="space-y-6" data-testid="tag-page">
          <UI.page_head :if={!@editing?}>
            <:prepend>
              <TagComponent.breadcrumbs
                render_root?={false}
                render_self?={false}
                scope={@current_scope}
                tag={@tag}
              />
            </:prepend>

            <div class="flex justify-between">
              <UI.page_title>{@tag.name}</UI.page_title>

              <UI.button_add_to_user
                :if={@tenant_context.current_membership && !@current_member_tagged?}
                data-testid="member-tagging-add"
                phx-click="tagging_create_start"
                data-tip="Add to my profile"
              />
            </div>
          </UI.page_head>

          <MembershipTagging.list_for_tag
            :if={@tagging_count > 0}
            active_sort={@selected_member_tagging_sort}
            query={@taggings_query}
            scope={@current_scope}
            tag={@tag}
          />

          <section :if={@editing? and @tag_form != nil}>
            <TagComponent.form
              action_label="Update tag"
              class="border border-accent rounded-box p-4 mb-6"
              event_submit="tag_submit"
              event_validate="tag_validate"
              form={@tag_form}
            />
          </section>

          <section :if={!@editing?} class="mt-12" data-testid="primary-block">
            <Markdown.editable
              block={@primary_block}
              cancel="primary_block_cancel"
              editing?={@primary_block_editing?}
              form={@primary_block_form}
              id="primary-block"
              page_tree={@page_tree}
              scope={@current_scope}
              submit="primary_block_submit"
              text={@primary_block_version_text}
            />
          </section>
        </div>
      </Layouts.space>
    </Layouts.app>

    <Modal.render
      cancel="tagging_form_cancel"
      cancel_testid="member-tagging-cancel"
      open?={@tagging_modal_open?}
      testid="member-tagging-dialog"
    >
      <MembershipTagging.form
        :if={@tagging_modal.mode == :create and @tagging_modal.form}
        action_label="Save"
        error={@tagging_modal.error}
        form={@tagging_modal.form}
        mode={@tagging_modal.mode}
        options={[@tag]}
        tag={@tag}
        membership={@tenant_context.current_membership}
        tenant={@current_scope.tenant}
      />
    </Modal.render>
    """
  end

  defp maybe_sync_tag_form(%{assigns: %{editing?: true}} = socket), do: open_tag_form(socket)
  defp maybe_sync_tag_form(socket), do: socket

  defp open_tag_form(%{assigns: %{tag: %Tag{} = tag, current_scope: scope}} = socket) do
    assign(socket, :tag_form, tag |> Form.for_update(:update, scope: scope) |> to_form())
  end

  defp open_tag_form(socket), do: socket

  defp close_tag_form(socket) do
    socket
    |> assign(:editing?, false)
    |> assign(:tag_form, nil)
  end

  defp assign_primary_block(socket, nil) do
    assign(socket,
      primary_block_author_membership: nil,
      primary_block: nil,
      primary_block_version: nil,
      primary_block_version_text: nil,
      primary_block_version_count: 0
    )
  end

  defp assign_primary_block(socket, block) do
    socket
    |> assign(:primary_block, block)
    |> assign_primary_block_history(block)
  end

  defp assign_primary_block_form(socket, block, params \\ %{}) do
    form =
      block
      |> Blocks.block_to_form_params(params, socket.assigns.page_tree)
      |> to_form(as: :block)

    assign(socket, :primary_block_form, form)
  end

  defp assign_primary_block_history(socket, block) do
    scope = socket.assigns.current_scope

    socket
    |> assign(:primary_block_version_count, count_primary_block_versions(block, scope))
    |> assign_primary_block_latest_version(block, scope)
  end

  defp assign_primary_block_latest_version(socket, block, scope) do
    case Blocks.load_version_latest(block, scope: scope) do
      {:ok, nil} ->
        assign(socket,
          primary_block_author_membership: nil,
          primary_block_version_text: nil,
          primary_block_version: nil
        )

      {:ok, version} ->
        assign_primary_block_selected_version(socket, block, version, scope)

      {:error, error} ->
        Log.scoped_error(scope, error, "tag primary block latest version load failed")

        assign(socket,
          primary_block_author_membership: nil,
          primary_block_version_text: nil,
          primary_block_version: nil
        )
    end
  end

  defp assign_primary_block_selected_version(socket, block, version, scope) do
    case Blocks.version_to_text(block, version, scope: scope) do
      {:ok, text} ->
        assign(socket,
          primary_block_author_membership:
            load_primary_block_author_membership(scope, version.author),
          primary_block_version_text: text,
          primary_block_version: version
        )

      {:error, error} ->
        Log.scoped_error(scope, error, "tag primary block version text load failed")
        socket
    end
  end

  defp count_primary_block_versions(block, scope) do
    case Blocks.count_versions(block, scope: scope) do
      {:ok, count} ->
        count

      {:error, error} ->
        Log.scoped_error(scope, error, "tag primary block version count failed")
        0
    end
  end

  defp load_primary_block_author_membership(scope, author) do
    case Accounts.get_membership(scope.tenant, author) do
      {:ok, membership} ->
        membership

      {:error, error} ->
        Log.scoped_error(scope, error, "tag primary block author membership load failed")
        nil
    end
  end

  defp load_primary_block(%Tag{} = tag, scope) do
    case Tags.get_primary_block(tag, scope: scope) do
      {:ok, block} ->
        block

      {:error, error} ->
        Log.scoped_error(scope, error, "tag primary block load failed")
        nil
    end
  end

  defp tag_params(%{"name" => name} = params),
    do: Map.put(params, "slug", Utils.Slugify.generate(name))

  defp tag_params(params), do: params

  defp init_tagging_form(%Tag{} = tag) do
    to_form(
      %{
        "tag_id" => tag.id,
        "interest_level" => "0",
        "skill_level" => "0",
        "description" => ""
      },
      as: :form
    )
  end

  defp close_tagging_form(socket) do
    assign(socket, :tagging_modal, new_tagging_modal())
  end

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
      _ -> {:error, "Enter valid levels."}
    end
  end

  defp save_tagging_entry(membership, tagging_params, socket) do
    scope = socket.assigns.current_scope

    attrs = %{
      description: tagging_params.description,
      dimensions: %{
        "interest" => tagging_params.interest_level,
        "skill" => tagging_params.skill_level
      }
    }

    result =
      if empty_dimensions?(attrs.dimensions) do
        remove_tagging_entry(membership, tagging_params.tag_id, scope)
      else
        Tags.upsert_tagging(membership, membership, tagging_params.tag_id, attrs, scope: scope)
      end

    case result do
      {:ok, _tagging} ->
        socket
        |> close_tagging_form()
        |> refresh_tagging_state()

      :ok ->
        socket
        |> close_tagging_form()
        |> refresh_tagging_state()

      {:error, :not_found} ->
        socket
        |> close_tagging_form()
        |> refresh_tagging_state()

      {:error, error} ->
        Log.scoped_error(scope, error, "tagging submit failed")

        assign_tagging_form_error(
          socket,
          normalize_tagging_form(%{}),
          "Couldn't save that tagging."
        )
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

  defp refresh_tagging_state(socket) do
    scope = socket.assigns.current_scope
    tag_graph = Tags.load_tag_graph(scope)

    socket
    |> assign_tag_graph_state(tag_graph, socket.assigns.tag)
    |> assign_current_member_tagging(socket.assigns.tag)
  end

  defp assign_current_member_tagging(socket, tag) do
    current_membership = socket.assigns.tenant_context.current_membership

    assign(
      socket,
      :current_member_tagged?,
      current_member_tagged?(current_membership, tag, socket.assigns.current_scope)
    )
  end

  defp current_member_tagged?(nil, _tag, _scope), do: false

  defp current_member_tagged?(current_membership, tag, scope) do
    case Tags.list_taggings(current_membership, scope: scope) do
      {:ok, taggings} ->
        Enum.any?(taggings, &(&1.tag_id == tag.id))

      {:error, error} ->
        Log.scoped_error(scope, error, "current member tagging lookup failed")
        false
    end
  end

  defp empty_dimensions?(dimensions) do
    dimensions
    |> Enum.reject(fn {_key, value} -> value == 0 end)
    |> Enum.empty?()
  end

  defp parse_level(params, key) do
    params
    |> Map.get(key, "0")
    |> Integer.parse()
    |> case do
      {level, ""} when level in 0..10 -> {:ok, level}
      _other -> :error
    end
  end

  defp tagging_count(tag_graph, tag) do
    tag_graph
    |> Map.get(:tags_by_id, %{})
    |> Map.get(tag.id, tag)
    |> Map.get(:membership_tagging_count, 0)
    |> Kernel.||(0)
  end

  defp assign_tag_graph_state(socket, tag_graph, tag) do
    socket
    |> assign(:tag_graph, tag_graph)
    |> assign(:tagging_count, tagging_count(tag_graph, tag))
    |> assign(:tag_page_taggings, tag_page_taggings(tag_graph, tag))
  end

  defp tag_page_taggings(tag_graph, tag) do
    tag_graph
    |> Map.get(:tags_by_id, %{})
    |> Map.get(tag.id, tag)
    |> Map.get(:page_taggings, [])
    |> Kernel.||([])
  end

  defp primary_block_version_label(nil, _count), do: "None"

  defp primary_block_version_label(version, count) when count > 0 do
    "#{version.revision}/#{count}"
  end

  defp primary_block_version_label(version, _count), do: "#{version.revision}"

  defp primary_block_timestamp(%{inserted_at: inserted_at}, _block), do: inserted_at
  defp primary_block_timestamp(_version, %{updated_at: updated_at}), do: updated_at

  defp primary_block_prev_disabled?(nil), do: true
  defp primary_block_prev_disabled?(version), do: version.revision <= 1

  defp primary_block_next_disabled?(nil, _count), do: true
  defp primary_block_next_disabled?(_version, count) when count <= 0, do: true
  defp primary_block_next_disabled?(version, count), do: version.revision >= count

  defp new_tagging_modal(mode \\ nil, attrs \\ []) do
    %{
      error: Keyword.get(attrs, :error),
      form: Keyword.get(attrs, :form),
      mode: mode
    }
  end
end
