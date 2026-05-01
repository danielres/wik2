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

      <div>
        <.action_button
          data-testid={"block-#{@placement.id}-info"}
          icon="hero-information-circle-micro"
          phx-click="show_block_info"
          phx-value-placement_id={@placement.id}
        />
        <.action_button
          :if={@placement.block.type == :markdown}
          icon="hero-clock-mini"
          phx-click="show_block_history"
          phx-value-placement_id={@placement.id}
          title="Show markdown history"
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

        <.action_button
          icon={
            if @placement.area == :aside,
              do: "hero-chevron-left-mini",
              else: "hero-chevron-right-mini"
          }
          phx-click="toggle_block_aside"
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
