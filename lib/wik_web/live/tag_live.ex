defmodule WikWeb.TagLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Phoenix.LiveView
  alias Utils.Log
  alias Wik.Blocks
  alias Wik.Tags
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag
  alias Wik.Wiki
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
     |> assign(tag_content_block: nil)
     |> assign(tag_content_form: nil)
     |> assign(tag_graph: nil)
     |> assign(tag_form: nil)
     |> assign(taggings_query: nil)
     |> assign(show_descendants?: false)}
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
          |> assign(:tag_content_block, tag_content_block)
          |> assign(:tag_content_form, nil)
          |> assign(:tag_graph, tag_graph)
          |> assign(:taggings_query, Tags.tag_taggings_query(tag))
          |> assign(:show_descendants?, GraphQueries.children_for(tag_graph, tag) != [])
          |> maybe_sync_tag_form()

        {:ok, nil} ->
          socket
          |> put_flash(:error, "Tag not found")
          |> push_navigate(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/tags")

        {:error, error} ->
          Log.scoped_error(socket.assigns.current_scope, error, "tag page load failed")

          socket
          |> put_flash(:error, "Couldn't load tag")
          |> push_navigate(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/tags")
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
         |> push_patch(to: ~p"/#{socket.assigns.current_scope.tenant.slug}/tags/#{tag.slug}")}

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
         |> assign(:tag_content_block, block)
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
         |> assign(:tag_content_block, block)
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
            <UI.button_ok phx-click="toggle_edit_mode" data-testid="tag-edit-mode-ok" />
          <% else %>
            <UI.button_unlock
              phx-click="toggle_edit_mode"
              data-testid="tag-edit-mode-toggle"
            />
          <% end %>
        </:actions>

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

          <section class="mb-12">
            <TagComponent.form
              :if={@editing? and @tag_form != nil}
              action_label="Update tag"
              class="border border-accent rounded-box p-4 mb-6"
              event_submit="tag_submit"
              event_validate="tag_validate"
              form={@tag_form}
            />

            <section :if={!@editing?} class="space-y-0" data-testid="tag-content">
              <div class="flex items-center justify-between gap-3">
                <h2 class="text-base font-semibold text-base-content/20 uppercase">
                  <span class="sr-only">Description</span>
                </h2>

                <div>
                  <UI.button_edit_soft
                    :if={@editable? and !@content_editing?}
                    class="absolute"
                    data-testid="tag-content-edit"
                    phx-click="tag_content_edit"
                  />
                </div>
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

              <div class="">
                <Markdown.render
                  :if={!@content_editing? and @tag_content_block != nil}
                  block={@tag_content_block}
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

          <div
            :if={not @editing?}
            class={[
              "grid sm:grid-cols-[3fr_1fr]",
              "[&>section:first-child]:border-base-content/20",
              "[&>section:first-child]:max-sm:border-b",
              "[&>section:first-child]:max-sm:pb-8",
              "[&>section:first-child]:max-sm:mb-8",
              "[&>section:first-child]:sm:border-r",
              "[&>section:first-child]:sm:pr-4",
              "[&>section:first-child]:sm:mr-4"
            ]}
          >
            <section>
              <h2 class="text-xl font-semibold mb-2">Members</h2>

              <MembershipTagging.list_for_tag
                active_sort={@selected_member_tagging_sort}
                query={@taggings_query}
                scope={@current_scope}
                tag={@tag}
              />
            </section>

            <section class="space-y-4">
              {# <TagComponent.parents scope={@current_scope} tag={@tag} />}
              <TagComponent.children graph={@tag_graph} scope={@current_scope} tag={@tag} />
              <TagComponent.descendants
                :if={@show_descendants?}
                graph={@tag_graph}
                scope={@current_scope}
                tag={@tag}
              />
            </section>
          </div>
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

  defp assign_tag_content_form(socket, block, params \\ %{}) do
    form =
      block
      |> Blocks.block_to_form_params(params, socket.assigns.page_tree)
      |> to_form(as: :block)

    assign(socket, :tag_content_form, form)
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
end
