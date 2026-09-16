defmodule WikWeb.PageLive.Components.LibraryEntries do
  use WikWeb, :html

  alias WikWeb.Components.Modal
  alias WikWeb.LibraryLive.Components.{EntryForm, EntryModal}
  alias WikWeb.LibraryLive.Components.EntryCard
  alias WikWeb.LibraryLive.EntryPresentation
  alias WikWeb.LibraryLive.State

  attr :actor_id, :string, required: true
  attr :admin?, :boolean, required: true
  attr :edit_error, :string, default: nil
  attr :edit_form, :map, default: nil
  attr :entry_error, :string, default: nil
  attr :entry_form, :map, default: nil
  attr :entry_form_media, :map, required: true
  attr :membership_id, :string, default: nil
  attr :mode, :atom, default: nil
  attr :picker_entries, :any, required: true
  attr :picker_form, :map, required: true
  attr :selected_entry_id, :string, default: nil
  attr :selected_playlist_video_id, :string, default: nil
  attr :selected_type_id, :string, default: nil
  attr :state, :map, required: true
  attr :topic_form, :map, default: nil
  attr :topics, :list, required: true

  def modal(assigns) do
    selected_entry = State.find_entry(assigns.state, assigns.selected_entry_id)

    assigns =
      assigns
      |> assign(:manageable?, manageable?(selected_entry, assigns.actor_id, assigns.admin?))
      |> assign(:selected_entry, selected_entry)
      |> assign(:selected_type, State.find_type_by_id(assigns.state, assigns.selected_type_id))
      |> assign(
        :topic_summaries,
        topic_summaries(
          assigns.state,
          selected_entry,
          assigns.selected_type_id,
          assigns.topics,
          assigns.membership_id
        )
      )
      |> assign(:title, modal_title(assigns.mode, assigns.state, assigns.selected_type_id))

    ~H"""
    <Modal.render
      :if={@mode in [:new, :picker]}
      cancel="library_entry:close_modal"
      cancel_testid="library-entry-modal-close"
      open?={@mode != nil}
      testid="library-entry-modal"
    >
      <:title>{@title}</:title>

      <div :if={@mode == :new && @selected_type} data-testid="library-entry-create">
        <p :if={@entry_error} class="mb-3 text-sm text-error" data-testid="library-entry-error">
          {@entry_error}
        </p>

        <EntryForm.render
          cancel_event="library_entry:cancel_create"
          change_event="library_entry:change_create"
          form={@entry_form}
          id="library-entry-create-form"
          mode={:new}
          submit_event="library_entry:create"
          submit_label="Create and add"
          testid="library-entry-create-form"
          type={@selected_type}
        />
      </div>

      <div :if={@mode == :picker && @selected_type} class="space-y-4">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-end">
          <.form
            for={@picker_form}
            id="library-entry-picker-search-form"
            class="min-w-0 flex-1"
            phx-change="library_entry:picker_search"
          >
            <.input
              field={@picker_form[:query]}
              label="Search"
              phx-debounce="200"
              placeholder={"Search #{@selected_type.name} entries"}
              type="search"
            />
          </.form>

          <button
            class="btn btn-accent btn-soft"
            data-testid="library-entry-picker-create"
            phx-click="library_entry:picker_create"
            type="button"
          >
            <.icon name="hero-plus-micro" /> Create new
          </button>
        </div>

        <div
          class="autogrid [--autogrid-min:13rem] gap-3"
          data-testid="library-entry-picker-results"
          id="library-entry-picker-results"
          phx-update="stream"
        >
          <div
            class="hidden only:block rounded-box border border-dashed border-base-content/20 p-8 text-center text-sm text-base-content/55"
            id="library-entry-picker-empty"
          >
            No matching entries yet.
          </div>

          <EntryCard.card
            :for={{dom_id, entry} <- @picker_entries}
            click_event="library_entry:picker_select"
            click_label={"Select #{EntryPresentation.title(@selected_type, entry)}"}
            click_testid={"library-entry-picker-select-#{entry.id}"}
            dom_id={dom_id}
            entry={entry}
            manageable?={false}
            owned?={entry.creator_id == @actor_id}
            testid={"library-entry-picker-card-#{entry.id}"}
            topic_summaries={[]}
            type={@selected_type}
          />
        </div>
      </div>
    </Modal.render>

    <EntryModal.render
      :if={@mode in [:detail, :edit] && @selected_entry && @selected_type}
      entry={@selected_entry}
      error={@edit_error}
      form={@edit_form}
      manageable?={@manageable?}
      metadata_error={@entry_form_media.error}
      metadata_loading?={@entry_form_media.loading?}
      mode={@mode}
      playlist_label={EntryPresentation.playlist_label(@selected_type, @selected_entry)}
      selected_playlist_video_id={@selected_playlist_video_id}
      topic_form={@topic_form}
      topic_options={@topics}
      topic_summaries={@topic_summaries}
      type={@selected_type}
    />
    """
  end

  defp topic_summaries(_state, nil, _type_id, _topics, _membership_id), do: []

  defp topic_summaries(state, entry, type_id, topics, membership_id) do
    type = State.find_type_by_id(state, type_id)
    State.topic_summaries(state, entry, type, topics, membership_id)
  end

  defp manageable?(nil, _actor_id, _admin?), do: false

  defp manageable?(entry, actor_id, admin?) do
    State.can_manage_entry?(entry, actor_id, admin?)
  end

  defp modal_title(:new, state, type_id) do
    case State.find_type_by_id(state, type_id) do
      nil -> "Create Library entry"
      type -> "Create #{type.name}"
    end
  end

  defp modal_title(:picker, state, type_id) do
    case State.find_type_by_id(state, type_id) do
      nil -> "Choose Library entry"
      type -> "Choose #{type.name}"
    end
  end

  defp modal_title(:detail, state, type_id) do
    case State.find_type_by_id(state, type_id) do
      nil -> "Library entry"
      type -> type.name
    end
  end

  defp modal_title(:edit, state, type_id) do
    case State.find_type_by_id(state, type_id) do
      nil -> "Edit Library entry"
      type -> "Edit #{type.name}"
    end
  end

  defp modal_title(_mode, _state, _type_id), do: "Library"
end
