defmodule QblogWeb.Components.Block.Types.Pages do
  use QblogWeb, :html

  alias QblogWeb.Components.Block.Types.Pages.FormState
  alias QblogWeb.Components.Block.Types.Pages.RenderState

  attr :block, :map, required: true
  attr :class, :any, default: ""
  attr :scope, :map, default: nil

  def render(assigns) do
    data = assigns.block.data
    scope = assigns.scope

    assigns = assigns |> assign(RenderState.build(scope, data))

    ~H"""
    <div class={[
      "border-1 border-base-300/60 rounded-box",
      "bg-white/80 dark:bg-base-300/20",
      "px-4 py-2",
      "[&>*]:space-y-4"
    ]}>
      <div
        :if={@source_node_missing?}
        class={["text-sm opacity-60 alert", @class]}
        data-testid="pages-source-missing"
      >
        <.icon name="hero-exclamation-triangle-mini" class="text-warning" /> Source node missing
      </div>

      <.tree_nodes :if={!@source_node_missing?} depth={1} nodes={@tree} scope={@scope} />
    </div>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true
  attr :scope, :map, default: nil

  def form_fields(assigns) do
    scope = assigns.scope
    source_node = assigns.form[:source_node].value

    assigns = assigns |> assign(FormState.build(scope, source_node))

    ~H"""
    <.input
      field={@form[:source_node]}
      id={"edit-block-source-node-#{@block.id}"}
      label="Source"
      options={@source_node_options}
      phx-mounted={JS.focus()}
      type="select"
      value={@selected_source_node}
    />

    <.input
      field={@form[:depth]}
      id={"edit-block-depth-#{@block.id}"}
      label="Depth"
      min="1"
      type="number"
    />
    """
  end

  attr :nodes, :list, required: true
  attr :scope, :map, required: true
  attr :depth, :integer, required: true

  defp tree_nodes(assigns) do
    ~H"""
    <ul class="space-y-0" data-depth={@depth}>
      <li :for={node <- @nodes}>
        <.link
          class={[
            "opacity-70 hover:opacity-100 transition-opacity"
          ]}
          data-depth={@depth}
          navigate={build_page_path(@scope, node.path)}
        >
          <.icon_branch :if={@depth > 1} /> {node.title}
        </.link>

        <div :if={node.children != []} class="pl-4">
          <.tree_nodes depth={@depth + 1} nodes={node.children} scope={@scope} />
        </div>
      </li>
    </ul>
    """
  end

  defp icon_branch(assigns) do
    ~H"""
    <.icon name="hero-chevron-right-mini" class={["rotate-135", "opacity-30"]} />
    """
  end

  defp build_page_path(%{tenant: tenant}, path) do
    "/" <> tenant.name <> "/wiki" <> "/" <> path
  end
end
