defmodule QblogWeb.PageTreeLive.Components.PagesTree.ActionButton do
  import QblogWeb.CoreComponents
  use Phoenix.Component

  attr :"data-tip", :string, required: true
  attr :"phx-click", :string, required: true
  attr :"phx-value-new_parent_id", :any, required: false
  attr :"phx-value-node_id", :integer, required: true
  attr :icon, :string, required: true
  attr :variant, :string, default: "primary"

  def render(assigns) do
    class =
      case assigns.variant do
        "error" -> "hover:btn-error"
        _ -> "hover:btn-primary"
      end

    assigns = assigns |> assign(class: class)

    ~H"""
    <.button
      class={[
        "btn btn-xs btn-circle",
        "tooltip",
        @class
      ]}
      {assigns}
    >
      <.icon name={@icon} />
      <span class="sr-only">{assigns[:"data-tip"]}</span>
    </.button>
    """
  end
end
