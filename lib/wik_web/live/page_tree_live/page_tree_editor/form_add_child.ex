defmodule WikWeb.PageTreeLive.PageTreeEditor.FormAddChild do
  use WikWeb, :live_component

  alias Utils.Log
  alias Wik.Wiki.PageTree
  alias WikWeb.Components.Page
  alias WikWeb.PageTreeLive.PageTreeEditor
  alias WikWeb.PageTreeLive.PageTreeEditor.FlowAddChild

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  attr(:current_scope, :any, required: true)
  attr(:editor_id, :string, required: true)
  attr(:flow, :map, required: true)
  attr(:page_tree, :map, required: true)

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} data-testid="add-child-modal">
      <h3 class="mb-2" data-testid="add-child-heading">
        <span>Add child under</span>
        <span class="font-bold" data-testid="add-child-parent-slug">
          "{parent_slug(@page_tree.nodes, @flow.parent_id)}"
        </span>
      </h3>

      <Page.node_title_form
        action_label="Add"
        event_submit="add_child"
        event_validate="add_child_validate"
        form={@flow.form}
        include_parent_id?
        parent_id={@flow.parent_id}
        testid_prefix="add-child"
        target={@myself}
      />
    </div>
    """
  end

  @impl true
  def handle_event("add_child", %{"form" => params}, socket) do
    flow = socket.assigns.flow
    page_tree = socket.assigns.page_tree
    scope = socket.assigns.current_scope

    case flow |> FlowAddChild.submit(page_tree, %{"form" => params}, scope) do
      {:ok, flow, page_tree} ->
        send(self(), {:page_tree_updated, page_tree})

        send_update(
          PageTreeEditor,
          id: socket.assigns.editor_id,
          flow_add_child: flow
        )

        {:noreply,
         socket
         |> assign(flow: flow, page_tree: page_tree)}

      {:error, flow, err} ->
        Log.scoped_error(scope, err, "page_tree add_child failed")
        {:noreply, socket |> assign(flow: flow)}
    end
  end

  @impl true
  def handle_event("add_child_validate", %{"form" => params}, socket) do
    {:noreply,
     socket
     |> assign(flow: socket.assigns.flow |> FlowAddChild.validate(params))}
  end

  defp parent_slug(_nodes, nil), do: "top"

  defp parent_slug(nodes, parent_id) do
    case PageTree.get_node(nodes, parent_id) do
      nil -> "unknown"
      node -> node.slug
    end
  end
end
