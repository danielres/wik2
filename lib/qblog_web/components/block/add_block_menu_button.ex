defmodule QblogWeb.Components.Block.AddBlockMenuButton do
  use QblogWeb, :html

  attr :class, :any, default: ""
  attr :id, :string, required: true
  attr :open?, :boolean, default: false

  def render(assigns) do
    ~H"""
    <.popover_special_blocks id={@id} open?={@open?} />

    <button
      class={@class}
      popovertarget={@id}
      style={ "anchor-name:--anchor-#{@id}" }
    >
      <.icon name="hero-ellipsis-horizontal-mini" />
    </button>
    """
  end

  attr :id, :string, required: true
  attr :open?, :boolean, default: false

  defp popover_special_blocks(assigns) do
    ~H"""
    <div
      popover
      id={@id}
      style={ "position-anchor:--anchor-#{@id}" }
      class={[
        "dropdown dropdown-top dropdown-end",
        @open? and "dropdown-open",
        "bg-base-300 rounded",
        "p-2",
        "border-1 border-base-300",
        "mb-1"
      ]}
    >
      <div class={[
        "grid",
        "[&_button]:justify-start",
        "rounded",
        "space-y-[1px]"
      ]}>
        <.button_special_block
          :for={block_type <- Qblog.Blocks.types_available()}
          label={block_type.label}
          phx-click="add_block"
          phx-value-type={block_type.type}
        />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :rest, :global

  defp button_special_block(assigns) do
    ~H"""
    <button
      {@rest}
      class="btn btn-primary btn-ghost btn-sm rounded-sm"
    >
      {@label}
    </button>
    """
  end
end
