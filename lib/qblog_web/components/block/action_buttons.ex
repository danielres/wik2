defmodule QblogWeb.Components.Block.ActionButtons do
  use QblogWeb, :html

  attr :placement, :map, required: true

  # TODO: set title attributes for buttons
  def render(assigns) do
    ~H"""
    <div class={[
      "bg-base-100/70 backdrop-blur"
    ]}>
      <button
        class={[
          "btn btn-square btn-ghost btn-xs hover:btn-primary",
          "opacity-50",
          "rounded-xs"
        ]}
        popovertarget={"popover-#{@placement.id}"}
        style={"anchor-name:--anchor-#{@placement.id}"}
        type="button"
      >
        <.icon name="hero-bars-3-micro" class="size-3" />
      </button>

      <div
        class={[
          "dropdown dropdown-left",
          "join",
          "bg-base-100/70 backdrop-blur",
          "rounded"
        ]}
        id={"popover-#{@placement.id}"}
        popover
        style={"position-anchor:--anchor-#{@placement.id}"}
      >
        <.action_button
          icon="hero-trash-mini"
          phx-click="destroy_block"
          phx-value-placement_id={@placement.id}
          variant="danger"
        />

        <.action_button
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
