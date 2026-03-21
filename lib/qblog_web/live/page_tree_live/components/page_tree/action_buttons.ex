defmodule QblogWeb.PageTreeLive.Components.PagesTree.ActionButtons do
  use Phoenix.Component
  alias QblogWeb.CoreComponents

  slot :inner_block, required: true

  def wrapper(assigns) do
    ~H"""
    <div class={[
      "flex flex-wrap gap-2",
      "[&_button]:opacity-50",
      "[&_button]:hover:opacity-100",
      "[&_button]:transition"
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :"data-tip", :string, required: true
  attr :"phx-click", :string, required: true
  attr :"phx-value-new_parent_id", :any, required: false
  attr :"phx-value-node_id", :integer, required: true
  attr :icon, :string, required: true
  attr :variant, :string, default: "primary"

  def button(assigns) do
    class =
      case assigns.variant do
        "error" -> "hover:btn-error"
        _ -> "hover:btn-primary"
      end

    assigns = assigns |> assign(class: class)

    ~H"""
    <CoreComponents.button
      class={[
        "btn btn-xs btn-circle",
        "tooltip tooltip-left",
        @class
      ]}
      {assigns}
    >
      <CoreComponents.icon name={@icon} />
      <span class="sr-only">{assigns[:"data-tip"]}</span>
    </CoreComponents.button>
    """
  end
end
