defmodule WikWeb.DocsLive do
  use WikWeb, :live_view

  alias WikWeb.Docs.Pages
  alias WikWeb.Components.UI

  @pages [
    Pages.Index,
    Pages.CoreFeatures
  ]

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(page: nil)

    {:ok, socket}
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  @impl true
  def render(assigns) do
    ~H"""
    <header class={[
      "bg-base-300 sticky top-0 z-40",
      "flex justify-between gap-2 items-center py-2",
      "px-4"
    ]}>
      <h1 class="flex items-center gap-2">
        <.link patch={~p"/docs"} class="text-xl">
          Wik docs
        </.link>
      </h1>
      <div class="w-26"><WikWeb.Layouts.theme_toggle /></div>
    </header>

    <UI.drawer>
      <:aside>
        <ul class="menu bg-base-200 min-h-full w-fit p-4 pr-8">
          <!-- Sidebar content here -->
          <li>
            <.link patch={~p"/docs"}>Wik?</.link>
          </li>
          <li>
            <.link patch={~p"/docs/core-features"}>Core features</.link>
          </li>
        </ul>
      </:aside>

      <main>
        <.container class="py-8">
          <div class="prose">
            <%= if @page do %>
              {render_page(@page, assigns)}
            <% else %>
              <p>Not found</p>
            <% end %>
          </div>
        </.container>
      </main>
    </UI.drawer>
    """
  end

  def container(assigns) do
    ~H"""
    <div class={[
      "max-w-prose-lg mx-auto px-4 sm:px-8",
      @class
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @impl true
  def handle_params(params, _url, socket) do
    page = get_page(Map.get(params, "path", []))

    {:noreply, assign(socket, page: page)}
  end

  defp render_page(page, assigns), do: page.render(assigns)

  defp get_page([]), do: get_page(["index"])

  defp get_page([slug]) when is_binary(slug) do
    Enum.find(@pages, &(&1.slug() == slug))
  end

  defp get_page(_path), do: nil
end
