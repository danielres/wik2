defmodule WikWeb.Components.Block.Types.LibraryEntry do
  use WikWeb, :html

  alias Wik.Library
  alias WikWeb.LibraryPrototypeLive.Components.EntryCard

  attr :block, :map, required: true
  attr :library_state, :map, default: nil
  attr :scope, :map, required: true

  def render(assigns) do
    reference = load_reference(assigns.block, assigns.scope)
    entry = current_entry(reference, assigns.library_state)

    assigns = assign(assigns, :entry, entry)

    ~H"""
    <div data-testid={"library-entry-block-content-#{@block.id}"} class="max-w-96">
      <EntryCard.card
        :if={@entry}
        click_event="library_entry:show"
        click_testid={"library-entry-open-#{@block.id}"}
        dom_id={"library-entry-card-#{@block.id}"}
        entry={@entry}
        manageable?={false}
        owned?={false}
        testid={"library-entry-card-#{@block.id}"}
        topic_summaries={[]}
        type={@entry.type}
      />

      <div :if={is_nil(@entry)} class="alert alert-soft text-sm" data-testid="library-entry-missing">
        <.icon name="hero-exclamation-triangle-micro" />
        <span>No Library entry is selected.</span>
      </div>
    </div>
    """
  end

  defp load_reference(block, scope) do
    case Library.get_block_reference(block.id, scope: scope) do
      {:ok, reference} -> reference
      _error -> nil
    end
  end

  defp current_entry(nil, _state), do: nil
  defp current_entry(reference, nil), do: reference.entry

  defp current_entry(reference, state) do
    WikWeb.LibraryPrototypeLive.State.find_entry(state, reference.entry_id) || reference.entry
  end
end
