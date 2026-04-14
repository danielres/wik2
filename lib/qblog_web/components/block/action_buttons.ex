defmodule QblogWeb.Components.Block.ActionButtons do
  use QblogWeb, :html

  attr :placement, :map, required: true

  # TODO: set title attributes for buttons
  def render(assigns) do
    ~H"""
    <div class="flex justify-between">
      <.action_button
        icon="hero-trash"
        phx-click="destroy_block"
        phx-value-placement_id={@placement.id}
        variant="danger"
      />

      <div class="join">
        <.action_button
          class="join-item"
          icon="hero-chevron-up-mini"
          phx-click="move_block_up"
          phx-value-placement_id={@placement.id}
        />

        <.action_button
          class="join-item"
          icon="hero-chevron-down-mini"
          phx-click="move_block_down"
          phx-value-placement_id={@placement.id}
        />

        <.action_button
          class="join-item"
          icon={
            if @placement.width == "half",
              do: "hero-arrows-pointing-out",
              else: "hero-arrows-pointing-in"
          }
          phx-click="toggle_block_width"
          phx-value-placement_id={@placement.id}
          title={if @placement.width == "half", do: "Set full width", else: "Set half width"}
        />

        <.action_button
          class="join-item"
          icon="hero-pencil-mini"
          phx-click="edit_block_start"
          phx-value-block_id={@placement.block.id}
        />
      </div>
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
        "btn btn-ghost btn-xs btn-square",
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
