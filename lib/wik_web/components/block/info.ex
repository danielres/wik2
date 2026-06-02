defmodule WikWeb.Components.Block.Info do
  use WikWeb, :html

  alias Wik.Wiki
  alias Wik.Wiki.PageTree
  alias WikWeb.Components

  attr :author_membership, :map, required: true
  attr :placement, :map, required: true
  attr :scope, :map, required: true

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :page_placements,
        block_page_placements(assigns.scope, assigns.placement.block.placements)
      )

    ~H"""
    <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 text-sm items-center">
      <dt class="opacity-60">ID</dt>
      <dd class="font-mono break-all" data-testid="block-info-id">
        {@placement.block.id}
      </dd>

      <dt class="opacity-60">Created</dt>
      <dd data-testid="block-info-inserted-at">
        <Components.Time.relative_and_precise
          datetime={@placement.block.inserted_at}
          direction="right"
          ago?
        />
      </dd>

      <dt class="opacity-60">By</dt>
      <dd data-testid="block-info-author" class="flex items-center gap-2">
        <Components.User.identity
          avatar_size="sm"
          class="gap-2"
          link?={true}
          membership={@author_membership}
        />
      </dd>
    </dl>

    <div class="mt-4 border-t border-base-300 pt-4 space-y-2">
      <h4 class="text-base">Placements</h4>

      <ul class="menu w-full" data-testid="block-info-placements">
        <li
          :for={page_placement <- @page_placements}
          data-testid={"block-info-placement-#{page_placement.id}"}
        >
          <.link
            :if={page_placement.kind == :linked}
            class=""
            navigate={~p"/#{@scope.tenant.slug}/wiki/#{page_placement.path}"}
          >
            <span>{page_placement.title}</span>
            <span class="opacity-60">{page_placement.path}</span>
          </.link>

          <span :if={page_placement.kind == :missing_path} class="opacity-60">
            Page path missing: <span class="font-mono">{page_placement.page_id}</span>
          </span>
        </li>
      </ul>
    </div>
    """
  end

  defp block_page_placements(scope, placements) do
    tree_nodes = scope |> Wiki.load_page_tree() |> Map.get(:nodes, [])

    nodes_by_page_id =
      tree_nodes
      |> Enum.filter(& &1.page_id)
      |> Map.new(&{&1.page_id, &1})

    placements
    |> Enum.filter(&(&1.attachable_type == "page"))
    |> Enum.map(&page_placement_to_info(&1, tree_nodes, nodes_by_page_id))
    |> Enum.sort_by(&page_placement_sort_key/1)
  end

  defp page_placement_to_info(placement, tree_nodes, nodes_by_page_id) do
    case Map.fetch(nodes_by_page_id, placement.attachable_id) do
      {:ok, node} ->
        %{
          id: placement.id,
          kind: :linked,
          path: PageTree.get_node_path(tree_nodes, node.id),
          title: node.title
        }

      :error ->
        %{id: placement.id, kind: :missing_path, page_id: placement.attachable_id}
    end
  end

  defp page_placement_sort_key(%{kind: :linked, path: path}), do: {0, path}
  defp page_placement_sort_key(%{kind: :missing_path, page_id: page_id}), do: {1, page_id}
end
