defmodule QblogWeb.Components.Block do
  use QblogWeb, :html

  alias QblogWeb.Components.Block

  # Dispatchers per block type =================================================

  attr :block, :map, required: true

  defp dispatch_render(assigns) do
    assigns.block.type |> type_to_module() |> then(& &1.render(assigns))
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  defp dispatch_form_fields(assigns) do
    assigns.block.type |> type_to_module() |> then(& &1.form_fields(assigns))
  end

  # Regular components =========================================================

  attr :placement, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="absolute top-0 right-0">
      <Block.ActionButtons.render placement={@placement} />
    </div>

    <.dispatch_render block={@placement.block} />
    """
  end

  # TODO: pass phx-submit and cancel_event (for phx-click) as attrs
  attr :form, :any, required: true
  attr :placement, :map, required: true

  def form(assigns) do
    assigns = assign_new(assigns, :block, fn -> assigns.placement.block end)

    ~H"""
    <Phoenix.Component.form
      for={@form}
      id={"edit-block-form-#{@block.id}"}
      phx-submit="edit_block_submit"
      phx-value-block_id={@block.id}
      class="bg-base-200 p-4 rounded-lg shadow-md space-y-4 ring-1 ring-opacity-5 ring-secondary"
    >
      <.dispatch_form_fields block={@block} form={@form} />

      <div class="flex justify-between gap-2">
        <.button
          class="btn btn-ghost btn-sm"
          phx-click="edit_block_cancel"
          phx-value-block_id={@block.id}
          type="button"
        >
          Cancel
        </.button>

        <.button class="btn btn-primary btn-sm" type="submit">Save</.button>
      </div>
    </Phoenix.Component.form>
    """
  end

  defp type_to_module(type) do
    Qblog.Blocks.Types.modules()
    |> Enum.find_value(fn
      module ->
        if module.type() == type do
          type_name = module |> Module.split() |> List.last()
          Module.concat([Block.Types, type_name])
        end
    end)
  end
end
