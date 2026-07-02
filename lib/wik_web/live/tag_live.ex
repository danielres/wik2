defmodule WikWeb.TagLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Phoenix.LiveView
  alias Utils.Log
  alias Wik.Accounts
  alias Wik.Blocks
  alias Wik.Tags
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag
  alias Wik.Wiki
  alias WikWeb.Components
  alias WikWeb.Components.Block.Types.Markdown
  alias WikWeb.Components.MembershipTagging
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
     |> assign(editable?: editable?)
     |> assign(content_editing?: false)
     |> assign(editing?: false)
     |> assign(page_tree: nil)
     |> assign(selected_member_tagging_sort: "interest_level")
     |> assign(tag: nil)
     |> assign(tag_content_author_membership: nil)
     |> assign(tag_content_block: nil)
     |> assign(tag_content_form: nil)
     |> assign(tag_content_selected_text: nil)
     |> assign(tag_content_version: nil)
     |> assign(tag_content_version_count: 0)
     |> assign(tag_graph: nil)
     |> assign(tag_form: nil)
     |> assign(taggings_query: nil)
     |> assign(show_descendants?: true)}
  end

  @impl true
  def handle_params(%{"tag_slug" => tag_slug}, url, socket) do
    socket =
      case Tags.get_tag_by_slug(tag_slug, scope: socket.assigns.current_scope) do
        {:ok, tag} when not is_nil(tag) ->
          scope = socket.assigns.current_scope
          tag_graph = Tags.load_tag_graph(socket.assigns.current_scope)
          page_tree = Wiki.load_page_tree(scope)
          tag_content_block = load_tag_content_block(tag, scope)

          socket
          |> assign(:tag, tag)
          |> assign(:content_editing?, false)
          |> assign(:page_tree, page_tree)
          |> assign(:tag_content_form, nil)
          |> assign_tag_content_block(tag_content_block)
          |> assign(:tag_graph, tag_graph)
          |> assign(:taggings_query, Tags.tag_taggings_query(tag))
          |> assign(:show_descendants?, GraphQueries.children_for(tag_graph, tag) != [])
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

  def handle_event("tag_content_edit", _params, socket) do
    scope = socket.assigns.current_scope

    case Tags.get_or_create_tag_content_block(socket.assigns.tag, scope: scope) do
      {:ok, %Tag{} = tag, block} ->
        {:noreply,
         socket
         |> assign(:tag, tag)
         |> assign_tag_content_block(block)
         |> assign(:content_editing?, true)
         |> assign_tag_content_form(block)}

      {:error, error} ->
        Log.scoped_error(scope, error, "tag content block creation failed")

        {:noreply,
         socket
         |> put_flash(:error, "Couldn't start editing tag content")}
    end
  end

  def handle_event("tag_content_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:content_editing?, false)
     |> assign(:tag_content_form, nil)}
  end

  def handle_event("tag_content_submit", %{"block" => params}, socket) do
    scope = socket.assigns.current_scope

    case Tags.update_tag_content_block(socket.assigns.tag, params, scope: scope) do
      {:ok, block} ->
        {:noreply,
         socket
         |> assign_tag_content_block(block)
         |> assign(:content_editing?, false)
         |> assign(:tag_content_form, nil)}

      {:error, error} ->
        Log.scoped_error(scope, error, "tag content update failed")

        {:noreply,
         socket
         |> put_flash(:error, "Couldn't update tag content")
         |> assign_tag_content_form(socket.assigns.tag_content_block, params)}
    end
  end

  def handle_event("tag_content_history_navigate", %{"direction" => direction}, socket)
      when direction in ["prev", "next"] do
    block = socket.assigns.tag_content_block
    version = socket.assigns.tag_content_version
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
        {:noreply, assign_tag_content_selected_version(socket, block, version, scope)}

      {:error, error} ->
        Log.scoped_error(scope, error, "tag content history navigation failed")
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
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
              :if={@editable? and !@content_editing?}
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
              :if={@editable? and !@content_editing?}
              class=""
              data-testid="tag-content-edit"
              phx-click="tag_content_edit"
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

          <section>
            <div class="flex justify-between items-baseline">
              <UI.panel_title>
                <div>History</div>
              </UI.panel_title>

              <div>
                <button
                  type="button"
                  data-testid="tag-content-history-prev"
                  phx-click="tag_content_history_navigate"
                  phx-value-direction="prev"
                  class={[
                    "hover:opacity-100 transition-opacity",
                    "cursor-pointer",
                    tag_content_prev_disabled?(@tag_content_version) &&
                      "pointer-events-none opacity-20",
                    !tag_content_prev_disabled?(@tag_content_version) &&
                      "opacity-50 hover:opacity-100"
                  ]}
                >
                  <span class="sr-only">prev</span>
                  <.icon name="hero-chevron-left-micro" />
                </button>

                <button
                  type="button"
                  data-testid="tag-content-history-next"
                  phx-click="tag_content_history_navigate"
                  phx-value-direction="next"
                  class={[
                    "transition-opacity",
                    "cursor-pointer",
                    tag_content_next_disabled?(@tag_content_version, @tag_content_version_count) &&
                      "pointer-events-none opacity-20",
                    !tag_content_next_disabled?(@tag_content_version, @tag_content_version_count) &&
                      "opacity-50 hover:opacity-100"
                  ]}
                >
                  <span class="sr-only">next</span>
                  <.icon name="hero-chevron-right-micro" />
                </button>

                <div
                  :if={@tag_content_block != nil}
                  class="badge badge-sm badge-neutral"
                >
                  <span class="opacity-60">v.</span>
                  <span data-testid="tag-content-version" class="text-xs opacity-60">
                    {tag_content_version_label(@tag_content_version, @tag_content_version_count)}
                  </span>
                </div>
              </div>
            </div>

            <div
              :if={@tag_content_block == nil}
              class="text-sm opacity-60"
              data-testid="tag-content-history-empty"
            >
              No content yet.
            </div>

            <div
              :if={@tag_content_block != nil}
              class="text-xs flex gap-2 justify-between"
              data-testid="tag-content-history"
            >
              <div data-testid="tag-content-author">
                <Components.User.identity
                  :if={@tag_content_author_membership}
                  avatar_size="xs"
                  class="gap-2"
                  link?
                  membership={@tag_content_author_membership}
                />
                <span :if={!@tag_content_author_membership} class="opacity-60">Unknown</span>
              </div>

              <div data-testid="tag-content-updated-at">
                <Components.Time.relative_and_precise
                  datetime={tag_content_timestamp(@tag_content_version, @tag_content_block)}
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

            <UI.page_title>{@tag.name}</UI.page_title>
          </UI.page_head>

          <UI.panel_title>Members</UI.panel_title>
          <MembershipTagging.list_for_tag
            active_sort={@selected_member_tagging_sort}
            query={@taggings_query}
            scope={@current_scope}
            tag={@tag}
          />

          <UI.panel_title class="pt-12 pb-6">Description</UI.panel_title>

          <section class="">
            <TagComponent.form
              :if={@editing? and @tag_form != nil}
              action_label="Update tag"
              class="border border-accent rounded-box p-4 mb-6"
              event_submit="tag_submit"
              event_validate="tag_validate"
              form={@tag_form}
            />

            <section :if={!@editing?} class="" data-testid="tag-content">
              <div class="flex items-center justify-between gap-3">
                <h2 class="text-base font-semibold text-base-content/20 uppercase">
                  <span class="sr-only">Description</span>
                </h2>

                <div></div>
              </div>

              <.form
                :if={@content_editing? and @tag_content_block != nil and @tag_content_form != nil}
                for={@tag_content_form}
                id="tag-content-form"
                phx-submit="tag_content_submit"
              >
                <Markdown.form_fields
                  block={@tag_content_block}
                  form={@tag_content_form}
                  page_tree={@page_tree}
                  scope={@current_scope}
                />

                <div class="mt-3 flex justify-end gap-2">
                  <button
                    class="btn btn-sm btn-ghost"
                    data-testid="tag-content-cancel"
                    phx-click="tag_content_cancel"
                    type="button"
                  >
                    Cancel
                  </button>

                  <button class="btn btn-sm btn-accent btn-soft" data-testid="tag-content-submit">
                    Save
                  </button>
                </div>
              </.form>

              <div class="flex gap-2 items-baseline justify-between">
                <Markdown.render
                  :if={!@content_editing? and @tag_content_block != nil}
                  block={tag_content_render_block(@tag_content_block, @tag_content_selected_text)}
                  page_tree={@page_tree}
                  scope={@current_scope}
                />
              </div>

              <div
                :if={!@content_editing? and @tag_content_block == nil}
                class="rounded-box border border-dashed border-base-content/20 p-4 text-sm opacity-60"
                data-testid="tag-content-empty"
              >
                No content yet.
              </div>
            </section>
          </section>
        </div>
      </Layouts.space>
    </Layouts.app>
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

  defp assign_tag_content_block(socket, nil) do
    assign(socket,
      tag_content_author_membership: nil,
      tag_content_block: nil,
      tag_content_version: nil,
      tag_content_selected_text: nil,
      tag_content_version_count: 0
    )
  end

  defp assign_tag_content_block(socket, block) do
    socket
    |> assign(:tag_content_block, block)
    |> assign_tag_content_history(block)
  end

  defp assign_tag_content_form(socket, block, params \\ %{}) do
    form =
      block
      |> Blocks.block_to_form_params(params, socket.assigns.page_tree)
      |> to_form(as: :block)

    assign(socket, :tag_content_form, form)
  end

  defp assign_tag_content_history(socket, block) do
    scope = socket.assigns.current_scope

    socket
    |> assign(:tag_content_version_count, count_tag_content_versions(block, scope))
    |> assign_tag_content_latest_version(block, scope)
  end

  defp assign_tag_content_latest_version(socket, block, scope) do
    case Blocks.load_version_latest(block, scope: scope) do
      {:ok, nil} ->
        assign(socket,
          tag_content_author_membership: nil,
          tag_content_selected_text: nil,
          tag_content_version: nil
        )

      {:ok, version} ->
        assign_tag_content_selected_version(socket, block, version, scope)

      {:error, error} ->
        Log.scoped_error(scope, error, "tag content latest version load failed")

        assign(socket,
          tag_content_author_membership: nil,
          tag_content_selected_text: nil,
          tag_content_version: nil
        )
    end
  end

  defp assign_tag_content_selected_version(socket, block, version, scope) do
    case Blocks.version_to_text(block, version, scope: scope) do
      {:ok, text} ->
        assign(socket,
          tag_content_author_membership:
            load_tag_content_author_membership(scope, version.author),
          tag_content_selected_text: text,
          tag_content_version: version
        )

      {:error, error} ->
        Log.scoped_error(scope, error, "tag content version text load failed")
        socket
    end
  end

  defp count_tag_content_versions(block, scope) do
    case Blocks.count_versions(block, scope: scope) do
      {:ok, count} ->
        count

      {:error, error} ->
        Log.scoped_error(scope, error, "tag content version count failed")
        0
    end
  end

  defp load_tag_content_author_membership(scope, author) do
    case Accounts.get_membership(scope.tenant, author) do
      {:ok, membership} ->
        membership

      {:error, error} ->
        Log.scoped_error(scope, error, "tag content author membership load failed")
        nil
    end
  end

  defp load_tag_content_block(%Tag{} = tag, scope) do
    case Tags.get_tag_content_block(tag, scope: scope) do
      {:ok, block} ->
        block

      {:error, error} ->
        Log.scoped_error(scope, error, "tag content block load failed")
        nil
    end
  end

  defp tag_params(%{"name" => name} = params),
    do: Map.put(params, "slug", Utils.Slugify.generate(name))

  defp tag_params(params), do: params

  defp tag_content_version_label(nil, _count), do: "None"

  defp tag_content_version_label(version, count) when count > 0 do
    "#{version.revision}/#{count}"
  end

  defp tag_content_version_label(version, _count), do: "#{version.revision}"

  defp tag_content_timestamp(%{inserted_at: inserted_at}, _block), do: inserted_at
  defp tag_content_timestamp(_version, %{updated_at: updated_at}), do: updated_at

  defp tag_content_prev_disabled?(nil), do: true
  defp tag_content_prev_disabled?(version), do: version.revision <= 1

  defp tag_content_next_disabled?(nil, _count), do: true
  defp tag_content_next_disabled?(_version, count) when count <= 0, do: true
  defp tag_content_next_disabled?(version, count), do: version.revision >= count

  defp tag_content_render_block(block, text) when is_binary(text) do
    %{block | data: %{"text" => text}}
  end

  defp tag_content_render_block(block, _text), do: block
end
