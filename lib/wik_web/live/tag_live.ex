defmodule WikWeb.TagLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Utils.Log
  alias Wik.Tags
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag
  alias WikWeb.Components.MembershipTagging
  alias WikWeb.Components.Tag, as: TagComponent
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    editable? = Ash.can?({Tag, :create}, socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(editable?: editable?)
     |> assign(editing?: false)
     |> assign(tag: nil)
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
          tag_graph = Tags.load_tag_graph(socket.assigns.current_scope)

          socket
          |> assign(:tag, tag)
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

            <div
              :if={not @editing? and @tag.description not in [nil, ""]}
              class="space-y-3 rounded-box opacity-80"
              data-testid="tag-page-description"
            >
              <div class="whitespace-pre-wrap">{@tag.description}</div>
            </div>
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

  defp tag_params(%{"name" => name} = params),
    do: Map.put(params, "slug", Utils.Slugify.generate(name))

  defp tag_params(params), do: params
end
