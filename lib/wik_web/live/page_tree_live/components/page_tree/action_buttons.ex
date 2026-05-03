defmodule WikWeb.PageTreeLive.Components.PageTree.ActionButtons do
  use Phoenix.Component
  alias WikWeb.CoreComponents

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
  attr :icon, :string, required: true
  attr :class, :string, default: ""
  attr :variant, :string, default: "accent"
  attr :rest, :global

  def button(assigns) do
    variant_class =
      case assigns.variant do
        "error" -> "hover:btn-error tooltip-error"
        _ -> "hover:btn-accent tooltip-accent"
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
      data-tip={assigns[:"data-tip"]}
      style="--tt-delay: 400ms"
      {@rest}
    >
      <CoreComponents.icon name={@icon} />
      <span class="sr-only">{assigns[:"data-tip"]}</span>
    </CoreComponents.button>
    """
  end
end
