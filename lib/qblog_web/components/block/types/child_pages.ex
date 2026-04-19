defmodule QblogWeb.Components.Block.Types.ChildPages do
  use QblogWeb, :html

  alias QblogWeb.Components.Block.Types.ChildPages.FormState
  alias QblogWeb.Components.Block.Types.ChildPages.RenderState

  attr :block, :map, required: true
  attr :class, :any, default: ""
  attr :node, :map, default: nil
  attr :path, :string, default: nil
  attr :scope, :map, default: nil

  def render(assigns) do
    scope = assigns.scope
    node = assigns.node
    path = assigns.path
    data = assigns.block.data

    assigns = assigns |> assign(RenderState.build(scope, node, path, data))

    ~H"""
    <div class={[
      "border-1 border-base-300/60 rounded-box",
      "bg-white/80 dark:bg-base-300/20",
      "px-4 py-2"
    ]}>
      <div
        :if={@source_node_missing?}
        class={["text-sm opacity-60 alert", @class]}
        data-testid="child-pages-source-missing"
      >
        <.icon name="hero-exclamation-triangle-mini" class="text-warning" /> Source page missing
      </div>

      <div :if={!@source_node_missing? and @child_nodes != []} class={@class}>
        <.link
          :if={@source_page}
          class="font-bold opacity-70 hover:opacity-100 transition-opacity"
          navigate={build_page_path(@scope, @source_page.path)}
        >
          {@source_page.title}
        </.link>

        <ul class="space-y-0">
          <li :for={child <- @child_nodes}>
            <.link
              class="opacity-70 hover:opacity-100 transition-opacity"
              navigate={build_page_path(@scope, child.path)}
            >
              <.icon_chevron /> {child.title}
            </.link>
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true
  attr :node, :map, default: nil
  attr :scope, :map, default: nil

  def form_fields(assigns) do
    scope = assigns.scope
    node = assigns.node
    form = assigns.form

    assigns = assigns |> assign(FormState.build(scope, node, form[:source_page].value))

    ~H"""
    <.input
      field={@form[:source_page]}
      id={"edit-block-source-page-#{@block.id}"}
      label="Source page"
      options={@source_page_options}
      phx-mounted={JS.focus()}
      type="select"
      value={@selected_source_page}
    />
    """
  end

  defp icon_chevron(assigns) do
    ~H"""
    <.icon name="hero-chevron-right-mini" class={["rotate-135", "opacity-30"]} />
    """
  end

  defp build_page_path(%{tenant: tenant}, path) do
    "/" <> tenant.name <> "/wiki" <> "/" <> path
  end
end
