defmodule WikWeb.Components.Block.Types.Backlinks do
  use WikWeb, :html

  alias Wik.Wiki.Backlinks
  alias WikWeb.Components.Page

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
    <div>
      <div :if={@missing_context?} class="text-sm opacity-60" data-testid="backlinks-missing-context">
        Backlinks block needs a page context.
      </div>

      <ul
        :if={!@missing_context?}
        class={[
          "space-y-1",
          "text-sm"
        ]}
        data-testid="backlinks-list"
      >
        <li>
          <.link
            navigate={"/" <> @scope.tenant.slug <> "/" <> "tree"}
            class="opacity-60 hover:opacity-100 transition-opacity"
          >
            All pages
          </.link>
        </li>

        <li :for={backlink <- @backlinks}>
          <Page.breadcrumbs node={backlink} page_tree={@page_tree} scope={@scope} />
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
end
