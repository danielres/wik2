defmodule WikWeb.Components.Time do
  @moduledoc """
  Renders a date and time in a human-friendly format.
  """
  use WikWeb, :html

  attr :ago?, :boolean, default: false
  attr :bg_class, :string, default: "bg-transparent"
  attr :class, :string, default: ""
  attr :datetime, :any, required: true
  attr :direction, :string, default: "bottom"
  attr :tooltip_variant_class, :string, default: ""
  attr :user_tz, :string, default: "Etc/UTC"

  def relative_and_precise(assigns) do
    direction_class =
      case assigns[:direction] do
        "left" -> "tooltip-left"
        "right" -> "tooltip-right"
        "top" -> "tooltip-top"
        "bottom" -> "tooltip-bottom"
        _ -> "tooltip-bottom"
      end

    precise_datetime =
      assigns.datetime
      |> Utils.Tz.to_local!(assigns.user_tz)
      |> Utils.Time.precise()

    assigns =
      assigns
      |> assign(direction_class: direction_class)
      |> assign(precise_datetime: precise_datetime)
      |> assign(relative_value: Utils.Time.relative(assigns.datetime))

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
          "cursor-pointer",
          @class
        ]}
        style="--tt-off: calc(100% + 0.1rem);"
      >
        {@relative_value}
        <span :if={@ago? && @relative_value != "just now"}>ago</span>

        <div class="tooltip-content text-xs">
          {@precise_datetime}
        </div>
      </span>
    </span>
    """
  end
end
