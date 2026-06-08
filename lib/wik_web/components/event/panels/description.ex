defmodule WikWeb.Components.Event.Panels.Description do
  use WikWeb, :html

  alias WikWeb.Components.TextContent

  attr :description, :string, default: nil

  def render(assigns) do
    ~H"""
    <WikWeb.Components.Event.Panel.render :if={@description not in [nil, ""]} title="Description">
      <div class={[
        "rounded-md bg-base-content/5 px-4 py-2 text-base-content/90",
        "text-xs leading-6"
      ]}>
        <TextContent.render text={@description} />
      </div>
    </WikWeb.Components.Event.Panel.render>
    """
  end
end
