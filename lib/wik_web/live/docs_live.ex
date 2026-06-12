defmodule WikWeb.DocsLive do
  use WikWeb, :live_view

  @docs_root Path.expand("../../docs", __DIR__)

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(path: nil)
      |> assign(html: "")

    {:ok, socket}
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

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

  def drawer(assigns) do
    ~H"""
    <div class="drawer sm:drawer-open">
      <input id="my-drawer-1" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content">
        {render_slot(@inner_block)}
      </div>

      <div class="drawer-side z-50">
        <label for="my-drawer-1" aria-label="close sidebar" class="drawer-overlay"></label>

        <ul class="menu bg-base-200 min-h-full w-fit p-4 pr-8">
          <!-- Sidebar content here -->
          <li>
            <.link patch={~p"/docs"}> Home </.link>
          </li>
          <li>
            <.link patch={~p"/docs/core-features"}>Core features</.link>
          </li>

          <li>
            <.link patch={~p"/docs/guides"}>Guides</.link>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <header class={[
      "bg-base-300 sticky top-0 z-40",
      "flex justify-between gap-2 items-center py-2",
      "px-4"
    ]}>
      <h1 class="flex items-center gap-2">
        <label for="my-drawer-1" class="btn drawer-button btn-xs sm:hidden">
          <.icon name="hero-bars-3-micro" />
          <span class="sr-only">Open drawer</span>
        </label>

        <.link patch={~p"/docs"} class="text-xl">
          Wik docs
        </.link>
      </h1>
      <div class="w-26"><WikWeb.Layouts.theme_toggle /></div>
    </header>

    <.drawer>
      <main>
        <.container class="py-8">
          <div class="prose">{@html}</div>
        </.container>
      </main>
    </.drawer>
    """
  end

  def handle_params(params, _url, socket) do
    segments = Map.get(params, "path", [])

    slug =
      case segments do
        [] -> "index"
        _ -> Path.join(segments)
      end

    candidate = Path.expand(Path.join(@docs_root, slug <> ".md"))
    safe? = String.starts_with?(candidate, @docs_root <> "/")

    {path, markdown} =
      if safe? do
        {candidate,
         case File.read(candidate) do
           {:ok, content} -> content
           {:error, :enoent} -> "not found"
           {:error, _} -> "error"
         end}
      else
        {nil, "not found"}
      end

    socket = assign(socket, path: path)

    {:ok, html, []} =
      Earmark.as_html(markdown, escape: true, smartypants: false)

    socket =
      socket
      |> assign(html: html |> Phoenix.HTML.raw())

    {:noreply, socket}
  end
end
