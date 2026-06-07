defmodule WikWeb.Components.Event.Panel do
  use WikWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="space-y-1">
      <div class={[
        "text-xs uppercase tracking-wide ",
        "flex gap-2 justify-between items-end"
      ]}>
        <span class="opacity-70">{@title}</span>
        {assigns[:actions] && render_slot(@actions)}
      </div>

      <div class="space-y-1">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
