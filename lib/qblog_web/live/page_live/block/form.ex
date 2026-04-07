defmodule QblogWeb.PageLive.Block.Form do
  use QblogWeb, :html

  alias QblogWeb.Blocks

  attr :form, :any, required: true
  attr :block, :map, required: true

  def render(assigns) do
    ~H"""
    <.form
      for={@form}
      id={"edit-block-form-#{@block.id}"}
      phx-submit="edit_block_submit"
      phx-value-block_id={@block.id}
    >
      <Blocks.Components.form_fields block={@block} form={@form} />

      <div class="flex justify-end gap-2">
        <.button
          class="btn btn-ghost"
          phx-click="edit_block_cancel"
          phx-value-block_id={@block.id}
          type="button"
        >
          Cancel
        </.button>

        <.button class="btn btn-primary" type="submit">Save</.button>
      </div>
    </.form>
    """
  end
end
