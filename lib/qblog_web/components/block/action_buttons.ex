defmodule QblogWeb.Components.Block.ActionButtons do
  use QblogWeb, :html

  attr :placement, :map, required: true

  def render(assigns) do
    ~H"""
    <div class="flex gap-1 justify-end opacity-50 hover:opacity-100 transition join">
      <.action_button
        icon="hero-trash-mini"
        phx-click="destroy_block"
        phx-value-placement_id={@placement.id}
        variant="danger"
      />

      <.action_button
        icon="hero-pencil-mini"
        phx-click="edit_block_start"
        phx-value-block_id={@placement.block.id}
      />

      <.action_button
        icon="hero-chevron-up-mini"
        phx-click="move_block_up"
        phx-value-placement_id={@placement.id}
      />

      <.action_button
        icon="hero-chevron-down-mini"
        phx-click="move_block_down"
        phx-value-placement_id={@placement.id}
      />
    </div>
    """
  end

  attr :rest, :global
  attr :icon, :string, required: true
  attr :variant, :string, default: "primary"

  defp action_button(assigns) do
    assigns =
      assign_new(assigns, :variant_class, fn ->
        case assigns.variant do
          "primary" -> "hover:btn-primary"
          "danger" -> "hover:btn-error"
          _ -> ""
        end
      end)

    ~H"""
    <.button
      {@rest}
      class={[
        "btn btn-xs btn-ghost btn-square",
        "join-item",
        @variant_class
      ]}
      type="button"
    >
      <.icon name={@icon} />
    </.button>
    """
  end
end
