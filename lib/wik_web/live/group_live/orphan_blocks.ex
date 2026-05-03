defmodule WikWeb.GroupLive.OrphanBlocks do
  use WikWeb, :html

  alias WikWeb.Components.Modal

  attr :event_orphan_block_destroy, :string, required: true
  attr :event_preview_cancel, :string, required: true
  attr :event_preview_start, :string, required: true
  attr :orphan_block_selected, :map, default: nil
  attr :orphan_blocks, :list, default: []
  attr :scope, :map, required: true

  def render(assigns) do
    ~H"""
    <Modal.render
      cancel={@event_preview_cancel}
      cancel_testid="orphan-block-preview-cancel"
      open?={@orphan_block_selected != nil}
      testid="orphan-block-preview-dialog"
    >
      <div :if={@orphan_block_selected} class="space-y-4">
        <div class="text-sm opacity-60">{@orphan_block_selected.id}</div>
        <WikWeb.Components.Block.preview block={@orphan_block_selected} scope={@scope} />
      </div>
    </Modal.render>

    <ul :if={@orphan_blocks != []} class="space-y-1">
      <li
        :for={block <- @orphan_blocks}
        class={[
          "btn",
          "flex items-center justify-between gap-2"
        ]}
      >
        <button
          phx-click={@event_preview_start}
          phx-value-block_id={block.id}
          class="px-4 py-2 flex-grow text-left cursor-pointer"
        >
          <div class="truncate">{block_summary(block)}</div>
        </button>

        <button
          :if={Ash.can?({block, :destroy}, @scope)}
          class={[
            "opacity-20 hover:opacity-100 transition-opacity",
            "hover:text-error",
            "cursor-pointer"
          ]}
          data-testid={"orphan-block-#{block.id}-destroy"}
          phx-click={@event_orphan_block_destroy}
          phx-value-block_id={block.id}
        >
          <.icon name="hero-trash-micro" class="size-4" />
        </button>
      </li>
    </ul>

    <div :if={@orphan_blocks == []} class="flex items-center justify-center py-8">
      <div>
        <.icon name="hero-check-micro" class="size-6 text-success" /> No orphan blocks.
      </div>
    </div>
    """
  end

  defp block_summary(%{type: :text, data: %{"text" => text}}) when is_binary(text) do
    text
    |> String.trim()
    |> case do
      "" -> "Empty text block"
      text -> text
    end
    |> String.slice(0, 40)
  end

  defp block_summary(block) do
    block.type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
