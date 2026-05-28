defmodule WikWeb.Components.Block.Types.Embed do
  use WikWeb, :html

  alias Wik.Blocks.Types.GoogleCalendar
  alias Wik.Blocks.Types.GoogleMaps
  alias Wik.Blocks.Types.SoundCloud
  alias Wik.Blocks.Types.YouTube

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    ~H"""
    <.input
      field={@form[:url]}
      id={"edit-block-url-#{@block.id}"}
      label="Embed URL or iframe code"
      phx-mounted={JS.focus()}
      type="textarea"
    />
    """
  end

  def wrapper(assigns) do
    # "border-2 border-base-200 rounded-box"
    ~H"""
    <div class={[
      "ring-1 ring-base-200/50",
      "rounded-box [&>*]:rounded-lg",
      "shadow"
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
