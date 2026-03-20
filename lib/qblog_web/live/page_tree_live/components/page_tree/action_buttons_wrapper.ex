defmodule QblogWeb.PageTreeLive.Components.PagesTree.ActionButtonsWrapper do
  use Phoenix.Component

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <div class={[
      "flex flex-wrap gap-2",
      "[&_button]:opacity-50",
      "[&_button]:hover:opacity-100",
      "[&_button]:transition"
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
