defmodule WikWeb.Components.Block.AddBlockMenuButton do
  use WikWeb, :html

  alias Wik.Blocks.Types.ChildPages
  alias Wik.Blocks.Types.Backlinks
  alias Wik.Blocks.Types.Embed
  alias Wik.Blocks.Types.Markdown
  alias Wik.Blocks.Types.Members
  alias Wik.Blocks.Types.Pages
  alias Wik.Wiki
  alias Wik.Wiki.PageTree
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI

  attr :event_open, :string, required: true

  def render(assigns) do
    ~H"""
    <UI.button_add phx-click={@event_open} />
    """
  end

  attr :child_pages_available?, :boolean, default: false
  attr :event_cancel, :string, required: true
  attr :event_position_select, :string, required: true
  attr :id, :string, required: true
  attr :open?, :boolean, default: false
  attr :position, :string, required: true
  attr :scope, :map, required: true

  def modal_special_blocks(assigns) do
    assigns =
      assign(
        assigns,
        :child_pages_available?,
        child_pages_available?(assigns.scope)
      )

    ~H"""
    <Modal.render
      cancel={@event_cancel}
      cancel_testid={"#{@id}-cancel"}
      open?={@open?}
      testid={@id}
    >
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div class="">
          <h3 class="font-bold mb-4">Add block to</h3>

          <div class={[
            "space-y-2"
          ]}>
            <label class={[
              "flex items-center gap-3 cursor-pointer label text-sm"
            ]}>
              <input
                checked={@position == "top"}
                class="radio radio-xs border-4 checked:border"
                name="add-block-position"
                phx-click={@event_position_select}
                phx-value-position="top"
                type="radio"
                value="top"
              />
              <span>Top of page</span>
            </label>

            <label class={[
              "flex items-center gap-3 cursor-pointer label text-sm"
            ]}>
              <input
                checked={@position == "bottom"}
                class="radio radio-xs border-4 checked:border"
                name="add-block-position"
                phx-click={@event_position_select}
                phx-value-position="bottom"
                type="radio"
                value="bottom"
              />
              <span>Bottom of page</span>
            </label>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-1">
          <div class={[
            "grid",
            "[&_button]:justify-start",
            "rounded",
            "space-y-1"
          ]}>
            <.button_special_block
              label={Markdown.label()}
              phx-click="add_block"
              phx-value-type="markdown"
            />

            <.button_special_block label={Embed.label()} phx-click="add_block" phx-value-type="embed" />

            <.button_special_block
              label={Pages.label()}
              phx-click="add_block"
              phx-value-type="pages"
            />

            <.button_special_block
              label={Backlinks.label()}
              phx-click="add_block"
              phx-value-type="backlinks"
            />
          </div>

          <div class={[
            "grid",
            "[&_button]:justify-start",
            "rounded",
            "space-y-1"
          ]}>
            <.button_special_block
              label={Members.label()}
              phx-click="add_block"
              phx-value-type="members"
            />

            <.button_special_block
              label="Linked copy"
              phx-click="add_block"
              phx-value-type="linked_copy"
            />

            <.button_special_block
              :if={@child_pages_available?}
              label={ChildPages.label()}
              phx-click="add_block"
              phx-value-type="child_pages"
            />
          </div>
        </div>
      </div>
    </Modal.render>
    """
  end

  attr :label, :string, required: true
  attr :rest, :global

  defp button_special_block(assigns) do
    ~H"""
    <button
      {@rest}
      class="btn hover:btn-primary btn-soft btn-sm rounded-sm"
    >
      {@label}
    </button>
    """
  end

  defp child_pages_available?(scope) do
    scope
    |> Wiki.load_page_tree()
    |> Map.get(:nodes, [])
    |> PageTree.get_nodes_with_child_pages()
    |> Enum.any?()
  end
end
