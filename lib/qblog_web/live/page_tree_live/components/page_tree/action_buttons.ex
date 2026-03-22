defmodule QblogWeb.PageTreeLive.Components.PageTree.ActionButtons do
  use Phoenix.Component
  alias QblogWeb.CoreComponents

  slot :inner_block, required: true

  def wrapper(assigns) do
    ~H"""
    <div class={[
      "flex flex-wrap gap-1",
      "[&_button]:opacity-70",
      "[&_button]:hover:opacity-100",
      "[&_button]:transition"
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  attr :"data-tip", :string, required: true
  attr :"phx-click", :string, required: true
  attr :"phx-target", :any, required: false
  attr :"phx-value-new_parent_id", :any, required: false
  attr :"phx-value-node_id", :any, required: true
  attr :icon, :string, required: true
  attr :variant, :string, default: "primary"
  attr :class, :string, default: ""

  def button(assigns) do
    variant_class =
      case assigns.variant do
        "error" -> "hover:btn-error tooltip-error"
        _ -> "hover:btn-primary tooltip-primary"
      end

    assigns = assigns |> assign(variant_class: variant_class)

    ~H"""
    <CoreComponents.button
      class={[
        "btn btn-xs btn-circle",
        "tooltip tooltip-left tooltip-delayed",
        @variant_class,
        @class
      ]}
      style="--tt-delay: 800ms"
      {assigns}
    >
      <CoreComponents.icon name={@icon} />
      <span class="sr-only">{assigns[:"data-tip"]}</span>
    </CoreComponents.button>
    """
  end
end
