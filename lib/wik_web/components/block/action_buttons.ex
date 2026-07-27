defmodule WikWeb.Components.Block.ActionButtons do
  use WikWeb, :html

  alias Wik.Blocks.Types

  attr :placement, :map, required: true

  # TODO: set title attributes for buttons
  def render(assigns) do
    ~H"""
    <div class="flex justify-between">
      <.action_button
        icon="hero-trash"
        phx-click="block:destroy"
        phx-value-placement_id={@placement.id}
        variant="danger"
      />

      <div>
        <.action_button
          :if={Types.supports_history?(@placement.block.type)}
          icon="hero-clock-mini"
          phx-click="block_history:show"
          phx-value-placement_id={@placement.id}
          title="Show history"
        />
        <.action_button
          data-testid={"block-#{@placement.id}-info"}
          icon="hero-information-circle-micro"
          phx-click="block_info:show"
          phx-value-placement_id={@placement.id}
        />
        <.action_button
          icon="hero-chevron-up-mini"
          phx-click="block:move_up"
          phx-value-placement_id={@placement.id}
        />

        <.action_button
          icon="hero-chevron-down-mini"
          phx-click="block:move_down"
          phx-value-placement_id={@placement.id}
        />

        <.action_button
          icon={
            if @placement.area == :aside,
              do: "hero-chevron-left-mini",
              else: "hero-chevron-right-mini"
          }
          phx-click="block:toggle_aside"
          phx-value-placement_id={@placement.id}
          title={if @placement.area == :aside, do: "Move to main column", else: "Move to aside"}
        />
      </div>
    </div>
    """
  end

  attr :rest, :global
  attr :icon, :string, required: true
  attr :variant, :string, default: "accent"

  defp action_button(assigns) do
    assigns =
      assign_new(assigns, :variant_class, fn ->
        case assigns.variant do
          "primary" -> "hover:btn-primary"
          "accent" -> "hover:btn-accent"
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
