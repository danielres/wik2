defmodule QblogWeb.PageLive.Components.BlockInfoModal do
  use QblogWeb, :html

  alias QblogWeb.Components

  attr :placement, :map, required: true
  attr :scope, :map, required: true

  def render(assigns) do
    ~H"""
    <Components.Modal.render
      cancel="hide_block_info"
      cancel_testid="block-info-cancel"
      open?={true}
      testid="block-info-dialog"
    >
      <:title>Block info</:title>

      <Components.Block.Info.render placement={@placement} scope={@scope} />
    </Components.Modal.render>
    """
  end
end
