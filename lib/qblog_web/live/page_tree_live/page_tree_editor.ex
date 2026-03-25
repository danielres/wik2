defmodule QblogWeb.PageTreeLive.PageTreeEditor do
  use QblogWeb, :live_component

  alias AshPhoenix.Form
  alias Qblog.Wiki
  alias Qblog.Wiki.PageTree
  alias QblogWeb.Components.Modal
  alias QblogWeb.PageTreeLive.Components
  alias QblogWeb.PageTreeLive.Components.AddChild
  alias QblogWeb.PageTreeLive.Components.MoveNode
  alias QblogWeb.PageTreeLive.Components.PageTree.ActionButtons
  alias QblogWeb.PageTreeLive.Helpers
  alias Utils.Log

  defp init_form_add_child(scope) do
    PageTree.Node |> Form.for_create(:create, scope: scope) |> to_form()
  end

  defp init_add_child_state(scope) do
    %{
      open?: false,
      parent_id: nil,
      form: init_form_add_child(scope)
    }
  end

  defp init_move_node_state do
    %{
      open?: false,
      node_id: nil
    }
  end

  @impl true
  def update(assigns, socket) do
    scope = assigns.current_scope

    socket =
      socket
      |> assign(assigns)
      |> assign_new(:move_node, fn -> init_move_node_state() end)
      |> assign_new(:add_child, fn -> init_add_child_state(scope) end)

    socket =
      case socket.assigns do
        %{page_tree: %PageTree{}} ->
          socket

        %{current_scope: scope} ->
          case Wiki.get_page_tree(scope: scope) do
            {:ok, page_tree} ->
              assign(socket, :page_tree, page_tree)

            {:error, err} ->
              Log.scoped_error(scope, err, "get_page_tree failed")
              assign(socket, :page_tree, %PageTree{nodes: []})
          end
      end

    {:ok, socket}
  end

  attr :current_scope, :any, required: true
  attr :editable?, :boolean, default: false

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div class="flex items-center justify-between gap-4">
        <h1 class="text-2xl font-[100]">Page Tree</h1>
        <ActionButtons.wrapper>
          <ActionButtons.button
            :if={@editable?}
            class="[&:not(:hover)]:bg-base-100"
            data-tip="add at top level"
            icon="hero-plus-mini"
            phx-click="add_child_start"
            phx-target={@myself}
            phx-value-node_id=""
          />
        </ActionButtons.wrapper>
      </div>

      <Modal.render
        cancel="move_node_cancel"
        open?={@move_node.open?}
        phx-target={@myself}
      >
        <:title>
          <h3 class="mb-2">
            <span>Move</span>
            <span class="font-bold">
              "{Helpers.get_node_by_id(@page_tree.nodes, @move_node.node_id).title}"
            </span>
          </h3>
        </:title>
        <MoveNode.dialog
          moved_node_id={@move_node.node_id}
          nodes_flat={@page_tree.nodes}
          target={@myself}
        />
      </Modal.render>

      <Modal.render
        cancel="add_child_cancel"
        open?={@add_child.open?}
        phx-target={@myself}
      >
        <:title>
          <span>Add child under</span>
          <span class="font-bold">
            {Helpers.get_node_by_id(@page_tree.nodes, @add_child.parent_id).slug}
          </span>
        </:title>
        <AddChild.dialog
          form={@add_child.form}
          parent_id={@add_child.parent_id}
          target={@myself}
        />
      </Modal.render>

      <Components.PageTree.render nodes_flat={@page_tree.nodes}>
        <:action_buttons :let={props}>
          <.action_buttons
            :if={@editable?}
            depth={props.depth}
            node={props.node}
            nodes_flat={@page_tree.nodes}
            phx-target={@myself}
          />
        </:action_buttons>
      </Components.PageTree.render>
    </div>
    """
  end

  attr :"phx-target", :any, required: false
  attr :depth, :integer, required: true
  attr :node, :map, required: true
  attr :nodes_flat, :list, required: true

  defp action_buttons(assigns) do
    candidates = Helpers.parent_options(assigns.nodes_flat, assigns.node.id)
    assigns = assigns |> assign(has_candidates?: candidates |> Enum.count() > 0)

    ~H"""
    <ActionButtons.wrapper>
      <ActionButtons.button
        :if={@node.children == []}
        data-tip="delete"
        icon="hero-x-mark-mini"
        phx-click="remove_node"
        phx-target={assigns[:"phx-target"]}
        phx-value-node_id={@node.id}
        variant="error"
      />

      <ActionButtons.button
        data-tip="add child"
        icon="hero-plus-mini"
        phx-click="add_child_start"
        phx-target={assigns[:"phx-target"]}
        phx-value-node_id={@node.id}
      />

      <ActionButtons.button
        :if={@has_candidates?}
        data-tip="move"
        icon="hero-arrow-turn-down-right-mini"
        phx-click="move_node_start"
        phx-target={assigns[:"phx-target"]}
        phx-value-node_id={@node.id}
      />
    </ActionButtons.wrapper>
    """
  end

  # dialog =======================================================================

  @impl true
  def handle_event("add_child_cancel", _params, socket) do
    {:noreply, socket |> assign(add_child: init_add_child_state(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("move_node_cancel", _params, socket) do
    {:noreply, socket |> assign(move_node: init_move_node_state())}
  end

  # add_child ==================================================================

  @impl true
  def handle_event("add_child_start", params, socket) do
    parent_id =
      case params["node_id"] do
        "" -> nil
        value -> value |> String.to_integer()
      end

    {:noreply,
     socket
     |> assign(add_child: %{socket.assigns.add_child | parent_id: parent_id, open?: true})}
  end

  @impl true
  def handle_event(
        "add_child",
        %{"form" => %{"parent_id" => node_id, "slug" => slug, "title" => title} = params},
        socket
      ) do
    scope = socket.assigns.current_scope
    parent_id = if node_id == "", do: nil, else: node_id

    case PageTree.add_child(
           socket.assigns.page_tree,
           parent_id,
           slug,
           title,
           scope: scope
         ) do
      {:ok, page_tree} ->
        {:noreply,
         socket
         |> assign(page_tree: page_tree)
         |> assign(add_child: init_add_child_state(scope))}

      {:error, err} ->
        Log.scoped_error(scope, err, "page_tree add_child failed")

        form =
          socket.assigns.add_child.form
          |> Form.validate(params)
          |> Form.add_error(err)

        {:noreply, socket |> assign(add_child: %{socket.assigns.add_child | form: form})}
    end
  end

  @impl true
  def handle_event("validate_child", %{"form" => params}, socket) do
    {:noreply,
     socket
     |> assign(
       add_child: %{
         socket.assigns.add_child
         | form: socket.assigns.add_child.form |> Form.validate(params)
       }
     )}
  end

  # move node ==================================================================

  @impl true
  def handle_event("move_node_start", params, socket) do
    {:noreply,
     socket
     |> assign(
       move_node: %{
         socket.assigns.move_node
         | node_id: params["node_id"] |> String.to_integer(),
           open?: true
       }
     )}
  end

  @impl true
  def handle_event("move_node", %{"new_parent_id" => new_parent_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.move_node(
           socket.assigns.page_tree,
           socket.assigns.move_node.node_id,
           new_parent_id,
           scope: scope
         ) do
      {:ok, page_tree} ->
        {:noreply,
         socket |> assign(page_tree: page_tree) |> assign(move_node: init_move_node_state())}

      {:error, err} ->
        Log.scoped_error(scope, err, "page_tree move_node failed")
        {:noreply, socket}
    end
  end

  # remove node ================================================================

  def handle_event("remove_node", %{"node_id" => node_id}, socket) do
    scope = socket.assigns.current_scope

    case PageTree.remove_node(socket.assigns.page_tree, node_id, scope: scope) do
      {:ok, page_tree} ->
        {:noreply, socket |> assign(page_tree: page_tree)}

      {:error, err} ->
        Log.scoped_error(scope, err, "page_tree remove_node failed")
        {:noreply, socket}
    end
  end
end
