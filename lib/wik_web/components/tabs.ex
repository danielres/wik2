defmodule WikWeb.Components.Tabs do
  use WikWeb, :html

  attr :active?, :boolean, default: false
  slot :inner_block, required: true
  attr :rest, :global, include: ~w(navigate patch replace)

  def tab(assigns) do
    ~H"""
    <.link
      class={["tab", @active? && "tab-active"]}
      role="tab"
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :active?, :boolean, default: false
  slot :inner_block, required: true

  def tab_content(assigns) do
    ~H"""
    <div class={[
      "tab-content",
      @active? && "block"
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
