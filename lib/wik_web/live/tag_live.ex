defmodule WikWeb.TagLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias Utils.Log
  alias Wik.Tags
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :tag, nil)}
  end

  @impl true
  def handle_params(%{"tag_slug" => tag_slug}, url, socket) do
    socket =
      case Tags.get_tag_by_slug(tag_slug, scope: socket.assigns.current_scope) do
        {:ok, tag} when not is_nil(tag) ->
          assign(socket, :tag, tag)

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
  def render(assigns) do
    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.group presences={@presences} scope={@current_scope} view="tags">
        <div :if={@tag} class="space-y-6" data-testid="tag-page">
          <div class="flex items-center gap-2 text-sm opacity-60">
            <.link navigate={~p"/#{@current_scope.tenant.slug}/tags"} class="hover:opacity-100">
              Tags
            </.link>
            <.icon name="hero-chevron-right-mini" class="opacity-50" />
            <span>{@tag.name}</span>
          </div>

          <section class="space-y-3 rounded-box bg-base-200/60 p-6">
            <UI.page_title>{@tag.name}</UI.page_title>

            <div class="text-xs font-mono opacity-50">
              /{@tag.slug}
            </div>

            <div
              :if={@tag.description not in [nil, ""]}
              class="rounded-box bg-base-100/70 p-4 text-sm/6 opacity-80 whitespace-pre-wrap"
              data-testid="tag-page-description"
            >
              {@tag.description}
            </div>

            <div :if={@tag.description in [nil, ""]} class="italic opacity-50">
              No description yet.
            </div>
          </section>
        </div>
      </Layouts.group>
    </Layouts.app>
    """
  end
end
