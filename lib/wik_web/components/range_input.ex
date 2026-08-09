defmodule WikWeb.Components.RangeInput do
  use WikWeb, :html

  attr :field, :any, required: true
  attr :id, :string, default: nil
  attr :label, :string, required: true
  attr :dimension, :map, required: true
  attr :max_level, :integer, required: true
  attr :min_level, :integer, default: 0

  def render(assigns) do
    assigns = assign(assigns, :input_id, assigns.id || assigns.field.id)

    ~H"""
    <div class="space-y-0">
      <div class="flex items-center justify-between gap-2">
        <label for={@input_id} class="label font-bold">{@label}</label>
        <%!-- <span class="badge badge-sm bg-base-100">{@field.value || "0"}</span> --%>
      </div>

      <input
        id={@input_id}
        name={@field.name}
        type="range"
        min={@min_level}
        max={@max_level}
        step="1"
        value={@field.value || "0"}
        class="range range-xs w-full"
        style={"color: #{@dimension.color};"}
      />
    </div>
    """
  end
end
