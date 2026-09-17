defmodule WikWeb.LibraryLive.Components.EntryModal do
  use WikWeb, :html

  alias WikWeb.Components.Modal
  alias WikWeb.LibraryLive.Components.EntryDetail

  attr :entry, :map, required: true
  attr :error, :string, default: nil
  attr :manageable?, :boolean, required: true
  attr :mode, :atom, required: true, values: [:detail, :edit]
  attr :playlist_label, :string, default: nil
  attr :selected_playlist_video_id, :string, default: nil
  attr :topic_form, :map, default: nil
  attr :topic_options, :list, required: true
  attr :topic_summaries, :list, required: true
  attr :type, :map, required: true
  slot :edit_form

  def render(assigns) do
    ~H"""
    <Modal.render
      cancel="modal:close"
      cancel_testid="library-modal-close"
      open?={true}
      testid="library-entry-dialog"
    >
      <:title>
        <div class="flex gap-4 justify-between items-baseline mt-1">
          <div class="line-clamp-2">
            {modal_title(@mode, @type, @entry)}
          </div>
          <div>
            <div
              :if={@mode == :detail}
              class={[
                "badge badge-sm bg-base-300",
                "text-xs small-caps text-base-content/60 whitespace-nowrap"
              ]}
            >
              {@type.name}
            </div>
          </div>
        </div>
      </:title>

      <p :if={@error} class="mb-3 text-sm text-error" data-testid="entry-modal-error">
        {@error}
      </p>

      <EntryDetail.render
        :if={@mode == :detail}
        entry={@entry}
        manageable?={@manageable?}
        playlist_label={@playlist_label}
        selected_playlist_video_id={@selected_playlist_video_id}
        topic_form={@topic_form}
        topic_options={@topic_options}
        topic_summaries={@topic_summaries}
        type={@type}
      />

      <div :if={@mode == :edit}>{render_slot(@edit_form)}</div>
    </Modal.render>
    """
  end

  defp modal_title(:detail, type, entry) do
    WikWeb.LibraryLive.EntryPresentation.title(type, entry)
  end

  defp modal_title(:edit, type, entry) do
    title = WikWeb.LibraryLive.EntryPresentation.title(type, entry)
    "Edit entry \"#{title}\""
  end
end
