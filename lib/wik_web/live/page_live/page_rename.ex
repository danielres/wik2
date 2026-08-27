defmodule WikWeb.PageLive.PageRename do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2]

  alias Utils.Log
  alias Wik.Wiki.PageTree
  alias WikWeb.Components.Page.RenameFormState

  def assign_defaults(socket), do: assign(socket, page_rename: RenameFormState.init())

  def open(socket) do
    node = socket.assigns.node
    scope = socket.assigns.current_scope

    assign(socket, page_rename: RenameFormState.open(node, scope))
  end

  def cancel(socket), do: assign(socket, page_rename: RenameFormState.init())

  def validate(socket, params) do
    page_rename = RenameFormState.validate(socket.assigns.page_rename, params)
    assign(socket, page_rename: page_rename)
  end

  def submit(socket, params) do
    page_rename = socket.assigns.page_rename
    node_id = page_rename.node_id
    page_tree = socket.assigns.page_tree
    scope = socket.assigns.current_scope

    case RenameFormState.submit(page_rename, page_tree, params, scope) do
      {:ok, page_rename, page_tree} ->
        path = PageTree.get_node_path(page_tree.nodes, node_id)
        target = "/#{scope.tenant.slug}/wiki/#{path}"

        socket
        |> assign(page_rename: page_rename)
        |> Phoenix.LiveView.push_navigate(to: target, replace: true)

      {:error, page_rename, error} ->
        Log.scoped_error(scope, error, "page_tree rename_node failed")
        assign(socket, page_rename: page_rename)
    end
  end
end
