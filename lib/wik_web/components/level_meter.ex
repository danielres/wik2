defmodule WikWeb.Components.LevelMeter do
  use WikWeb, :html

  attr :label, :string, required: true
  attr :level, :integer, required: true
  attr :dimension, :map, required: true
  attr :testid, :string, required: true
  attr :class, :string, default: ""
  attr :width_class, :string, default: "min-w-16"

  def render(assigns) do
    assigns = assign(assigns, :percentage, meter_value(assigns.level, assigns.dimension.max))

    ~H"""
    <div class={["flex min-w-0 items-center gap-1", @class]}>
      <div
        class={[
          "tooltip flex-1 leading-none",
          @width_class
        ]}
        style={"--tt-bg: color-mix(#{@dimension.color} 0%, var(--color-base-300))"}
      >
        <div class="tooltip-content">
          <div class="text-xs font-bold">
            <span>{@label}:</span>
            <span>{"#{@level}/#{@dimension.max}"}</span>
          </div>
        </div>

        <div
          role="progressbar"
          aria-label={@label}
          aria-valuemin="0"
          aria-valuemax={@dimension.max}
          aria-valuenow={@level}
          data-testid={@testid}
          class="h-2 w-full min-w-0 overflow-hidden rounded-full bg-base-300"
        >
          <div
            class="h-full rounded-full transition-[width] duration-300"
            style={"width: #{@percentage}%; background-color: #{@dimension.color}"}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp meter_value(level, max_level)
       when is_integer(level) and is_integer(max_level) and max_level > 0 do
    level
    |> Kernel./(max_level)
    |> Kernel.*(100)
    |> min(100)
    |> max(0)
  end

  defp meter_value(_level, _max_level), do: 0
end
