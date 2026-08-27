defmodule WikWeb.PageLive.PageRename do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2, to_form: 1]

  alias AshPhoenix.Form
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Node
  alias Utils.Log

  def assign_defaults(socket), do: assign(socket, page_rename_form: nil)

  def open(socket) do
    node = socket.assigns.node
    scope = socket.assigns.current_scope

    form =
      Node
      |> Form.for_create(:create,
        params: %{"slug" => node.slug, "title" => node.title},
        scope: scope
      )
      |> to_form()

    assign(socket, page_rename_form: form)
  end

  def cancel(socket), do: assign(socket, page_rename_form: nil)

  def validate(socket, params) do
    form = Form.validate(socket.assigns.page_rename_form, params)
    assign(socket, page_rename_form: form)
  end

  def submit(socket, %{"slug" => slug, "title" => title} = params) do
    node = socket.assigns.node
    page_tree = socket.assigns.page_tree
    scope = socket.assigns.current_scope

    case PageTree.rename_node(page_tree, node.id, slug, title, scope: scope) do
      {:ok, page_tree} ->
        path = PageTree.get_node_path(page_tree.nodes, node.id)
        target = "/#{scope.tenant.slug}/wiki/#{path}"

        socket
        |> assign(page_rename_form: nil)
        |> Phoenix.LiveView.push_navigate(to: target, replace: true)

      {:error, error} ->
        Log.scoped_error(scope, error, "page_tree rename_node failed")

        form =
          socket.assigns.page_rename_form
          |> Form.validate(params)
          |> Form.add_error(error)

        assign(socket, page_rename_form: form)
    end
  end
end
