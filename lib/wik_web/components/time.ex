defmodule WikWeb.Components.Time do
  @moduledoc """
  Renders a date and time in a human-friendly format.
  """
  use WikWeb, :html

  attr :datetime, :any, required: true
  attr :ago?, :boolean, default: false
  attr :direction, :string, default: "bottom"
  attr :bg_class, :string, default: "bg-transparent"
  attr :tooltip_variant_class, :string, default: ""

  def relative_and_precise(assigns) do
    direction_class =
      case assigns[:direction] do
        "left" -> "tooltip-left"
        "right" -> "tooltip-right"
        "top" -> "tooltip-top"
        "bottom" -> "tooltip-bottom"
        _ -> "tooltip-bottom"
      end

    assigns = assigns |> assign(direction_class: direction_class)

    ~H"""
    <span>
      <span
        class={[
          "underline decoration-dashed underline-offset-4",
          @bg_class,
          "opacity-60 hover:opacity-100 transition-opacity",
          "whitespace-nowrap",
          "tooltip tooltip-delayed tooltip-xs",
          @direction_class,
          @tooltip_variant_class,
          "cursor-pointer"
        ]}
        style="--tt-off: calc(100% + 0.1rem);"
      >
        {Utils.Time.relative(@datetime)}
        <span :if={@ago?}>ago</span>

        <div class="tooltip-content text-xs">
          {Utils.Time.precise(@datetime)}
        </div>
      </span>
    </span>
    """
  end
end
