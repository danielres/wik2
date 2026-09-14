defmodule WikWeb.PageLive.Components.LibraryEntries do
  use WikWeb, :html

  alias Phoenix.LiveView.JS
  alias WikWeb.Components.Modal

  alias WikWeb.LibraryPrototypeLive.Components.{EntryCard, EntryDetail, EntryForm}
  alias WikWeb.LibraryPrototypeLive.EntryPresentation
  alias WikWeb.LibraryPrototypeLive.State

  attr :actor_id, :string, required: true
  attr :admin?, :boolean, required: true
  attr :editing?, :boolean, required: true
  attr :focused_placement_id, :string, default: nil
  attr :id, :string, required: true
  attr :page_block_editing?, :boolean, required: true
  attr :placements, :any, required: true
  attr :state, :map, required: true

  def placement_list(assigns) do
    ~H"""
    <div class="flex flex-col gap-4" id={@id} phx-update="stream">
      <%= for {dom_id, placement} <- @placements do %>
        <div
          id={dom_id}
          data-testid={"library-entry-block-#{placement.id}"}
          phx-mounted={if(@focused_placement_id == placement.id, do: JS.focus(), else: nil)}
          tabindex="-1"
        >
          <%= if view = placement_view(@state, placement) do %>
            <.placement
              actor_id={@actor_id}
              admin?={@admin?}
              editing?={@editing?}
              entry={view.entry}
              page_block_editing?={@page_block_editing?}
              placement={placement}
              type={view.type}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :actor_id, :string, required: true
  attr :admin?, :boolean, required: true
  attr :editing?, :boolean, required: true
  attr :entry, :map, required: true
  attr :page_block_editing?, :boolean, required: true
  attr :placement, :map, required: true
  attr :type, :map, required: true

  defp placement(assigns) do
    assigns =
      assign(
        assigns,
        :manageable?,
        State.can_manage_entry?(assigns.entry, assigns.actor_id, assigns.admin?)
      )

    ~H"""
    <div class={[
      "space-y-2 transition",
      @page_block_editing? && "pointer-events-none opacity-50"
    ]}>
      <div
        :if={@editing?}
        class="flex items-center justify-between rounded-box bg-base-200/70 px-2 py-1"
        data-testid={"library-entry-actions-#{@placement.id}"}
      >
        <button
          aria-label="Remove Library entry block"
          class="btn btn-ghost btn-xs btn-square hover:btn-error"
          data-testid={"library-entry-remove-#{@placement.id}"}
          disabled={@page_block_editing?}
          phx-click="library_entry:remove"
          phx-value-placement_id={@placement.id}
          type="button"
        >
          <.icon name="hero-trash" />
        </button>

        <div class="flex items-center gap-1">
          <button
            :if={@manageable?}
            aria-label="Edit Library entry"
            class="btn btn-ghost btn-xs btn-square hover:btn-accent"
            data-testid={"library-entry-edit-#{@placement.id}"}
            disabled={@page_block_editing?}
            phx-click="library_entry:start_edit"
            phx-value-placement_id={@placement.id}
            type="button"
          >
            <.icon name="hero-pencil-micro" />
          </button>
          <button
            aria-label="Move Library entry block up"
            class="btn btn-ghost btn-xs btn-square hover:btn-accent"
            data-testid={"library-entry-move-up-#{@placement.id}"}
            disabled={@placement.first? || @page_block_editing?}
            phx-click="library_entry:move"
            phx-value-direction="up"
            phx-value-placement_id={@placement.id}
            type="button"
          >
            <.icon name="hero-chevron-up-mini" />
          </button>
          <button
            aria-label="Move Library entry block down"
            class="btn btn-ghost btn-xs btn-square hover:btn-accent"
            data-testid={"library-entry-move-down-#{@placement.id}"}
            disabled={@placement.last? || @page_block_editing?}
            phx-click="library_entry:move"
            phx-value-direction="down"
            phx-value-placement_id={@placement.id}
            type="button"
          >
            <.icon name="hero-chevron-down-mini" />
          </button>
        </div>
      </div>

      <EntryCard.card
        click_event={if(@editing?, do: nil, else: "library_entry:show")}
        click_testid={"library-entry-open-#{@placement.id}"}
        dom_id={"library-entry-card-#{@placement.id}"}
        entry={@entry}
        manageable?={@manageable?}
        owned?={@entry.creator_id == @actor_id}
        testid={"library-entry-card-#{@placement.id}"}
        topic_summaries={[]}
        type={@type}
      />
    </div>
    """
  end

  attr :admin?, :boolean, required: true
  attr :edit_error, :string, default: nil
  attr :edit_form, :map, default: nil
  attr :entry_error, :string, default: nil
  attr :entry_form, :map, default: nil
  attr :mode, :atom, default: nil
  attr :picker_entries, :any, required: true
  attr :picker_form, :map, required: true
  attr :selected_entry_id, :string, default: nil
  attr :selected_playlist_video_id, :string, default: nil
  attr :selected_type_id, :string, default: nil
  attr :state, :map, required: true

  def modal(assigns) do
    assigns =
      assigns
      |> assign(:selected_entry, State.find_entry(assigns.state, assigns.selected_entry_id))
      |> assign(:selected_type, State.find_type_by_id(assigns.state, assigns.selected_type_id))
      |> assign(:title, modal_title(assigns.mode, assigns.state, assigns.selected_type_id))

    ~H"""
    <Modal.render
      cancel="library_entry:close_modal"
      cancel_testid="library-entry-modal-close"
      open?={@mode != nil}
      testid="library-entry-modal"
    >
      <:title>{@title}</:title>

      <div :if={@mode == :chooser && @selected_type} data-testid="library-entry-chooser">
        <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
          <button
            class="btn btn-sm btn-ghost"
            data-testid="library-entry-back"
            phx-click="library_entry:back_to_block_menu"
            type="button"
          >
            <.icon name="hero-arrow-left-micro" /> Back
          </button>

          <button
            :if={State.can_create_entry?(@selected_type, @admin?)}
            class="btn btn-sm btn-accent btn-soft"
            data-testid="library-entry-create-new"
            phx-click="library_entry:start_create"
            type="button"
          >
            <.icon name="hero-plus-micro" /> Create new {@selected_type.name}
          </button>
        </div>

        <.form
          class="mb-4"
          for={@picker_form}
          id="library-entry-search-form"
          phx-change="library_entry:search"
        >
          <.input
            autocomplete="off"
            field={@picker_form[:query]}
            label="Search entries"
            phx-debounce="200"
            placeholder={"Search #{@selected_type.name}"}
            type="search"
          />
        </.form>

        <div
          class="autogrid grid grid-flow-row-dense gap-3 [--autogrid-min:14rem]"
          id="library-entry-picker-results"
          phx-update="stream"
        >
          <div
            class="hidden rounded-box border border-dashed border-base-content/20 py-12 text-center only:block"
            id="library-entry-picker-empty"
          >
            <.icon name="hero-magnifying-glass-micro" class="mx-auto size-6 opacity-25" />
            <p class="mt-2 text-sm text-base-content/50">No matching entries</p>
          </div>

          <EntryCard.card
            :for={{dom_id, entry} <- @picker_entries}
            click_event="library_entry:insert"
            click_label={"Insert #{EntryPresentation.title(@selected_type, entry)}"}
            click_testid={"library-entry-select-#{entry.id}"}
            dom_id={dom_id}
            entry={entry}
            manageable?={false}
            owned?={false}
            testid={"library-picker-entry-#{entry.id}"}
            topic_summaries={[]}
            type={@selected_type}
          />
        </div>
      </div>

      <div :if={@mode == :new && @selected_type} data-testid="library-entry-create">
        <p :if={@entry_error} class="mb-3 text-sm text-error" data-testid="library-entry-error">
          {@entry_error}
        </p>

        <EntryForm.render
          cancel_event="library_entry:back_to_chooser"
          change_event="library_entry:change_create"
          form={@entry_form}
          id="library-entry-create-form"
          mode={:new}
          submit_event="library_entry:create"
          submit_label="Create and insert"
          testid="library-entry-create-form"
          type={@selected_type}
        />
      </div>

      <div :if={@mode == :edit && @selected_type && @selected_entry} data-testid="library-entry-edit">
        <div
          class="alert alert-info alert-soft mb-4 text-sm"
          data-testid="library-entry-shared-edit-notice"
        >
          <.icon name="hero-arrow-path-rounded-square-micro" class="size-4" />
          <span>Editing this Library entry updates it everywhere it is used.</span>
        </div>

        <p :if={@edit_error} class="mb-3 text-sm text-error" data-testid="library-entry-edit-error">
          {@edit_error}
        </p>

        <EntryForm.render
          cancel_event="library_entry:cancel_edit"
          change_event="library_entry:change_edit"
          form={@edit_form}
          id="library-entry-edit-form"
          mode={:edit}
          submit_event="library_entry:save_edit"
          submit_label="Save library entry"
          testid="library-entry-edit-form"
          type={@selected_type}
        />
      </div>

      <EntryDetail.render
        :if={@mode == :detail && @selected_entry && @selected_type}
        entry={@selected_entry}
        manageable?={false}
        playlist_label={EntryPresentation.playlist_label(@selected_type, @selected_entry)}
        playlist_play_event="library_entry:playlist_play"
        selected_playlist_video_id={@selected_playlist_video_id}
        show_topics?={false}
        topic_options={[]}
        topic_summaries={[]}
        type={@selected_type}
      />
    </Modal.render>
    """
  end

  defp placement_view(state, placement) do
    with %{} = entry <- State.find_entry(state, placement.entry_id),
         %{} = type <- State.find_type_by_id(state, entry.type_id) do
      %{entry: entry, type: type}
    else
      _missing -> nil
    end
  end

  defp modal_title(:chooser, state, type_id) do
    case State.find_type_by_id(state, type_id) do
      nil -> "Choose a Library entry"
      type -> "Add #{type.name} from Library"
    end
  end

  defp modal_title(:new, state, type_id) do
    case State.find_type_by_id(state, type_id) do
      nil -> "Create Library entry"
      type -> "Create #{type.name}"
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
