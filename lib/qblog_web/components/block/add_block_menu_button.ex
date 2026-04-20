defmodule QblogWeb.Components.Block.AddBlockMenuButton do
  use QblogWeb, :html

  alias Qblog.Blocks.Types.ChildPages
  alias Qblog.Blocks.Types.Embed
  alias Qblog.Blocks.Types.Markdown
  alias Qblog.Blocks.Types.Members
  alias Qblog.Blocks.Types.Pages
  alias Qblog.Wiki
  alias Qblog.Wiki.PageTree.TreeQueries
  alias QblogWeb.Components.Modal

  attr :class, :any, default: ""
  attr :event_cancel, :string, required: true
  attr :event_open, :string, required: true
  attr :id, :string, required: true
  attr :open?, :boolean, default: false
  attr :scope, :map, required: true

  def render(assigns) do
    assigns =
      assign(
        assigns,
        :child_pages_available?,
        child_pages_available?(assigns.scope)
      )

    ~H"""
    <.modal_special_blocks
      child_pages_available?={@child_pages_available?}
      event_cancel={@event_cancel}
      id={@id}
      open?={@open?}
    />

    <button
      class={@class}
      phx-click={@event_open}
    >
      <.icon name="hero-plus-mini" />
    </button>
    """
  end

  attr :child_pages_available?, :boolean, default: false
  attr :event_cancel, :string, required: true
  attr :id, :string, required: true
  attr :open?, :boolean, default: false

  defp modal_special_blocks(assigns) do
    ~H"""
    <Modal.render
      cancel={@event_cancel}
      cancel_testid={"#{@id}-cancel"}
      open?={@open?}
      testid={@id}
    >
      <:title>Add block</:title>

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
    </Modal.render>
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

  defp child_pages_available?(scope) do
    scope
    |> Wiki.load_page_tree()
    |> Map.get(:nodes, [])
    |> TreeQueries.get_nodes_with_child_pages()
    |> Enum.any?()
  end
end
