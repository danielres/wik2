defmodule WikWeb.Components.Block.AddBlockMenuButton do
  use WikWeb, :html

  alias Wik.Blocks.Types.Backlinks
  alias Wik.Blocks.Types.ChildPages
  alias Wik.Blocks.Types.GoogleCalendar
  alias Wik.Blocks.Types.GoogleMaps
  alias Wik.Blocks.Types.Markdown
  alias Wik.Blocks.Types.Members
  alias Wik.Blocks.Types.Pages
  alias Wik.Blocks.Types.SoundCloud
  alias Wik.Blocks.Types.YouTube
  alias Wik.Wiki
  alias Wik.Wiki.PageTree
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI

  attr :class, :string, default: ""
  attr :event_open, :string, required: true
  attr :position, :string, required: true, values: ~w(top bottom)

  def render(assigns) do
    ~H"""
    <button
      class={["btn btn-sm btn-accent btn-soft", @class]}
      phx-click={@event_open}
      phx-value-position={@position}
    >
      <.icon name="hero-plus-micro" /> Add block
    </button>
    """
  end

  attr :child_pages_available?, :boolean, default: false
  attr :event_cancel, :string, required: true
  attr :id, :string, required: true
  attr :open?, :boolean, default: false
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
      <div class="grid gap-1">
        <div class={[
          "[&_button]:justify-start",
          "rounded",
          "space-y-6"
        ]}>
          <section>
            <UI.panel_title>Regular content</UI.panel_title>

            <.button_special_block
              label={Markdown.label()}
              phx-click="block:add"
              phx-value-type="markdown"
            />
          </section>

          <section>
            <UI.panel_title>Embeds</UI.panel_title>

            <.button_special_block
              label={YouTube.label()}
              phx-click="block:add"
              phx-value-type="youtube"
            />

            <.button_special_block
              label={SoundCloud.label()}
              phx-click="block:add"
              phx-value-type="soundcloud"
            />

            <.button_special_block
              label={GoogleCalendar.label()}
              phx-click="block:add"
              phx-value-type="google_calendar"
            />

            <.button_special_block
              label={GoogleMaps.label()}
              phx-click="block:add"
              phx-value-type="google_maps"
            />
          </section>

          <section>
            <UI.panel_title>Special blocks</UI.panel_title>

            <.button_special_block
              label={Pages.label()}
              phx-click="block:add"
              phx-value-type="pages"
            />

            <.button_special_block
              label={Backlinks.label()}
              phx-click="block:add"
              phx-value-type="backlinks"
            />

            <.button_special_block
              label={Members.label()}
              phx-click="block:add"
              phx-value-type="members"
            />

            <.button_special_block
              label="Linked copy"
              phx-click="block:add"
              phx-value-type="linked_copy"
            />

            <.button_special_block
              :if={@child_pages_available?}
              label={ChildPages.label()}
              phx-click="block:add"
              phx-value-type="child_pages"
            />
          </section>
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
