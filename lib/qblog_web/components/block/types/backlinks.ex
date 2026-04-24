defmodule QblogWeb.Components.Block.Types.Backlinks do
  use QblogWeb, :html

  alias Qblog.Wiki.Backlinks

  attr :block, :map, required: true
  attr :node, :map, default: nil
  attr :page_tree, :map, default: nil
  attr :scope, :map, default: nil

  def render(assigns) do
    assigns =
      case load_backlinks(assigns.scope, assigns.node, assigns.page_tree) do
        {:ok, backlinks} ->
          assigns
          |> assign(:backlinks, backlinks)
          |> assign(:missing_context?, false)

        :missing_context ->
          assigns
          |> assign(:backlinks, [])
          |> assign(:missing_context?, true)
      end

    ~H"""
    <div class={[
      "border-1 border-base-300/60 rounded-box",
      "bg-white/80 dark:bg-base-300/20",
      "px-4 py-2"
    ]}>
      <div :if={@missing_context?} class="text-sm opacity-60" data-testid="backlinks-missing-context">
        Backlinks block needs a page context.
      </div>

      <div
        :if={!@missing_context? and @backlinks == []}
        class="text-sm opacity-60"
        data-testid="backlinks-empty"
      >
        No backlinks yet
      </div>

      <ul :if={!@missing_context? and @backlinks != []} class="space-y-0" data-testid="backlinks-list">
        <li :for={backlink <- @backlinks}>
          <.link
            class="opacity-70 hover:opacity-100 transition-opacity"
            navigate={build_page_path(@scope, backlink.path)}
          >
            <.icon name="hero-arrow-uturn-left-micro" class={["opacity-30", "-scale-x-100"]} />
            {backlink.title}
          </.link>
        </li>
      </ul>
    </div>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    ~H"""
    <div class="text-sm opacity-70">
      This block renders pages linking to the current page.
    </div>
    """
  end

  defp load_backlinks(%{tenant: _tenant} = scope, %{page_id: _page_id} = node, page_tree)
       when not is_nil(page_tree) do
    case Backlinks.list_pages_linking_to_node(scope, node, page_tree) do
      {:ok, backlinks} -> {:ok, backlinks}
      {:error, _error} -> {:ok, []}
    end
  end

  defp load_backlinks(_scope, _node, _page_tree), do: :missing_context

  defp build_page_path(%{tenant: tenant}, path) do
    "/" <> tenant.name <> "/wiki" <> "/" <> path
  end
end
