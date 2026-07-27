defmodule WikWeb.PageLive.Components.BlockInfoModal do
  use WikWeb, :html

  alias WikWeb.Components

  attr :author_membership, :map, default: nil
  attr :placement, :map, required: true
  attr :scope, :map, required: true

  def render(assigns) do
    ~H"""
    <Components.Modal.render
      cancel="block_info:hide"
      cancel_testid="block-info-cancel"
      open?={true}
      testid="block-info-dialog"
    >
      <:title>Block info</:title>

      <Components.Block.Info.render
        author_membership={@author_membership}
        placement={@placement}
        scope={@scope}
      />
    </Components.Modal.render>
    """
  end
end
