defmodule QblogWeb.Components.Time do
  @moduledoc """
  Renders a date and time in a human-friendly format.
  """
  use QblogWeb, :html

  attr :datetime, :any, required: true
  attr :ago?, :boolean, default: false
  attr :direction, :string, default: "bottom"
  attr :bg_class, :string, default: "bg-base-300"
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
          "badge badge-sm px-2",
          @bg_class,
          "opacity-60 hover:opacity-100 transition-opacity",
          "whitespace-nowrap",
          "tooltip tooltip-delayed tooltip-xs",
          @direction_class,
          @tooltip_variant_class,
          "cursor-default"
        ]}
        style="--tt-off: calc(100% + 0.1rem);"
      >
        {Utils.Time.relative(@datetime)}

        <div class="tooltip-content text-xs">
          {Utils.Time.precise(@datetime)}
        </div>
      </span>
      <span :if={@ago?}>ago</span>
    </span>
    """
  end
end
