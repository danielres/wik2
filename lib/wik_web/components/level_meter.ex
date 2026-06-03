defmodule WikWeb.Components.LevelMeter do
  use WikWeb, :html

  attr :label, :string, required: true
  attr :level, :integer, required: true
  attr :dimension, :map, required: true
  attr :testid, :string, required: true
  attr :width_class, :string, default: "w-24"

  def render(assigns) do
    ~H"""
    <div class="flex items-center gap-1">
      <div
        class="tooltip leading-none"
        style={"--tt-bg: color-mix(#{@dimension.color} 0%, var(--color-base-300))"}
      >
        <div class="tooltip-content">
          <div class="font-bold text-xs">
            <span>{@label}:</span>
            <span>{"#{@level}/#{@dimension.max}"}</span>
          </div>
        </div>

        <progress
          class={["progress", @width_class]}
          data-testid={@testid}
          style={"color: #{@dimension.color};"}
          value={meter_value(@level, @dimension.max)}
          max="100"
        >
        </progress>
      </div>
    </div>
    """
  end

  defp meter_value(level, max_level)
       when is_integer(level) and is_integer(max_level) and max_level > 0 do
    trunc(level / max_level * 100)
  end

  defp meter_value(_level, _max_level), do: 0
end
