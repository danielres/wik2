defmodule WikWeb.PageLive.Components.BlockInfoModal do
  use WikWeb, :html

  alias Wik.Accounts
  alias WikWeb.Components

  attr :placement, :map, required: true
  attr :scope, :map, required: true

  def render(assigns) do
    {:ok, author_membership} =
      Accounts.get_membership(assigns.scope.tenant, assigns.placement.block.author)

    assigns = assign(assigns, :author_membership, author_membership)

    ~H"""
    <Components.Modal.render
      cancel="hide_block_info"
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
