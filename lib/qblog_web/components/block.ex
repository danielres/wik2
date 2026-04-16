defmodule QblogWeb.Components.Block do
  use QblogWeb, :html

  alias Qblog.Blocks
  alias QblogWeb.Components

  # Dispatchers per block type =================================================

  defp dispatch_render(assigns) do
    assigns.block.type |> type_to_module() |> then(& &1.render(assigns))
  end

  defp dispatch_form_fields(assigns) do
    assigns.block.type |> type_to_module() |> then(& &1.form_fields(assigns))
  end

  # Regular components =========================================================

  attr :block, :map, required: true

  def preview(assigns) do
    ~H"""
    <div class="rounded bg-base-200/50 p-4">
      <.dispatch_render block={@block} />
    </div>
    """
  end

  attr :lock, :map, default: nil
  attr :placement, :map, required: true
  attr :editing?, :boolean, default: false
  attr :node, :map, default: nil
  attr :path, :string, default: nil
  attr :scope, :map, default: nil

  def render(assigns) do
    ~H"""
    <div class={[
      "relative",
      "[&:has(>.ACTION-BUTTONS:hover)_.BLOCK]:ring-secondary/70",
      "@container/block"
    ]}>
      <div
        :if={@lock}
        class="absolute left-0 top-0 z-10 rounded-br-md bg-warning/85 px-2 py-1 text-xs font-medium text-warning-content shadow-sm"
      >
        {to_string(@lock.user)} editing
      </div>

      <div
        :if={@editing? and is_nil(@lock)}
        class={[
          "ACTION-BUTTONS",
          "opacity-50 hover:opacity-100 transition-opacity"
        ]}
      >
        <Components.Block.ActionButtons.render placement={@placement} />
      </div>

      <div class={[
        "BLOCK",
        @editing? and "ring-2",
        "rounded ring-secondary/10 transition"
      ]}>
        <.dispatch_render
          block={@placement.block}
          node={@node}
          path={@path}
          scope={@scope}
        />
      </div>
    </div>
    """
  end

  # TODO: pass phx-submit and cancel_event (for phx-click) as attrs
  attr :form, :any, required: true
  attr :placement, :map, required: true
  attr :node, :map, default: nil
  attr :path, :string, default: nil
  attr :scope, :map, default: nil

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
      <.dispatch_form_fields
        block={@block}
        form={@form}
        node={@node}
        path={@path}
        scope={@scope}
      />

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
    Blocks.Types.modules()
    |> Enum.find_value(fn
      module ->
        if module.type() == type do
          type_name = module |> Module.split() |> List.last()
          Module.concat([Components.Block.Types, type_name])
        end
    end)
  end
end
