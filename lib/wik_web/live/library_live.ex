defmodule WikWeb.LibraryLive do
  use WikWeb, :live_view

  alias Wik.Locations
  alias Wik.Tags
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI

  alias WikWeb.LibraryLive.Components.{
    EntryCard,
    EntryForm,
    EntryModal,
    LibraryToolbar,
    PortableSchema,
    SchemaSettings,
    TopicMatching,
    TypeList,
    TypePicker,
    TypeWizard
  }

  alias WikWeb.LibraryLive.EntryFormMedia
  alias WikWeb.LibraryLive.EntryPresentation
  alias WikWeb.LibraryLive.ExternalMedia
  alias WikWeb.LibraryLive.Schema
  alias WikWeb.LibraryLive.State
  alias WikWeb.TenantContext
  on_mount {WikWeb.LiveUserAuth, :live_scope_required}

  @admin_actions [:topic_matching, :type_new, :type_settings, :types]

  @impl true
  def mount(_params, _session, socket) do
    state = State.new(socket.assigns.current_scope)
    topics = load_topics(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:active_topic_ids, [])
     |> assign(:active_type_ids, [])
     |> assign(:can_manage_types?, space_admin?(socket))
     |> assign(:current_type, nil)
     |> assign(:editing_field, nil)
     |> assign(:entry_form, entry_form(nil))
     |> assign(:entry_form_media, EntryFormMedia.reset())
     |> assign(:entry_error, nil)
     |> assign(:entry_list_signature, nil)
     |> assign(:entry_mode, nil)
     |> assign(:expanded_topic_id, nil)
     |> assign(:field_form, field_form(nil))
     |> assign(:field_usage_counts, %{})
     |> assign(:import_form, to_form(%{"json" => ""}, as: :schema))
     |> assign(:library_state, state)
     |> assign(:selected_entry, nil)
     |> assign(:selected_playlist_video_id, nil)
     |> assign(:topic_form, nil)
     |> assign(:topics, topics)
     |> assign(:type_form, type_form(nil))
     |> assign(:wizard_draft, nil)
     |> stream(:entries, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state = socket.assigns.library_state
    filter_topics = State.assigned_topics(state, socket.assigns.topics)
    active_topic_ids = filter_ids(params["topics"], filter_topics)
    active_type_ids = filter_ids(params["types"], state.types)
    selected_entry = selected_entry(state, params["entry_id"])
    current_type = selected_type(state, params, selected_entry)
    entry_mode = route_entry_mode(socket.assigns.live_action, selected_entry)

    cond do
      socket.assigns.live_action in @admin_actions and not socket.assigns.can_manage_types? ->
        {:noreply,
         socket
         |> put_flash(:error, "Only space administrators can manage Library settings.")
         |> push_patch(to: library_path(socket))}

      socket.assigns.live_action == :entry_new and available_types(socket) == [] ->
        {:noreply,
         socket
         |> put_flash(:error, "No entry types are available.")
         |> push_patch(to: library_path(socket))}

      socket.assigns.live_action == :entry_edit and
          not can_manage_entry?(
            socket.assigns.current_scope.actor.id,
            selected_entry,
            socket.assigns.can_manage_types?
          ) ->
        {:noreply,
         socket
         |> put_flash(:error, "You can edit or delete only your own entries.")
         |> push_patch(to: library_path(socket))}

      socket.assigns.live_action == :type_settings and current_type == nil ->
        {:noreply, push_patch(socket, to: types_path(socket))}

      true ->
        socket =
          socket
          |> assign(:active_topic_ids, active_topic_ids)
          |> assign(:active_type_ids, active_type_ids)
          |> assign(:current_type, current_type)
          |> assign(:entry_mode, entry_mode)
          |> assign(:entry_error, nil)
          |> assign(:selected_entry, selected_entry)
          |> assign(:selected_playlist_video_id, nil)
          |> assign(:topic_form, nil)
          |> assign_route_forms()
          |> assign_route_entry_form()
          |> refresh_entries_if_changed()

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    state = assigns.library_state
    types = State.types_with_counts(state)
    filter_topics = State.assigned_topics_with_counts(state, assigns.topics)
    current_membership_id = current_membership_id(assigns)

    current_type_entry_count =
      if assigns.current_type, do: State.count_entries(state, assigns.current_type.id), else: 0

    assigns =
      assigns
      |> assign(:active_topics, selected_items(filter_topics, assigns.active_topic_ids))
      |> assign(:active_types, selected_items(types, assigns.active_type_ids))
      |> assign(:available_types, available_types(assigns))
      |> assign(:current_membership_id, current_membership_id)
      |> assign(:current_type_entry_count, current_type_entry_count)
      |> assign(:filter_topics, filter_topics)
      |> assign(
        :playlist_label,
        EntryPresentation.playlist_label(assigns.current_type, assigns.selected_entry)
      )
      |> assign(:topic_summaries, selected_entry_topic_summaries(assigns, current_membership_id))
      |> assign(:topic_views, topic_views(state, assigns.topics))
      |> assign(:types, types)

    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      scope={@current_scope}
      tenant_context={@tenant_context}
    >
      <Layouts.space scope={@current_scope} view="libraries">
        <main class="space-y-4" data-testid="library-page">
          <.render_content {assigns} />
        </main>
      </Layouts.space>
    </Layouts.app>

    <Modal.render
      :if={@entry_mode in [:type_picker, :new]}
      cancel="modal:close"
      cancel_testid="library-modal-close"
      open?={@entry_mode != nil}
      testid="library-entry-dialog"
    >
      <:title>
        <div class="flex gap-4 justify-between items-baseline mt-1">
          <div class="line-clamp-2">
            {entry_modal_title(@entry_mode, @current_type, @selected_entry)}
          </div>
          <div :if={@current_type}>
            <div
              :if={@entry_mode == :detail && @selected_entry}
              class={[
                "badge badge-sm bg-base-300",
                "text-xs small-caps text-base-content/60 whitespace-nowrap"
              ]}
            >
              {@current_type.name}
            </div>
          </div>
        </div>
      </:title>

      <TypePicker.render :if={@entry_mode == :type_picker} types={@available_types} />

      <EntryForm.render
        :if={@entry_mode == :new}
        form={@entry_form}
        metadata_error={@entry_form_media.error}
        metadata_loading?={@entry_form_media.loading?}
        mode={@entry_mode}
        type={@current_type}
      />
    </Modal.render>

    <EntryModal.render
      :if={@entry_mode in [:detail, :edit] && @selected_entry && @current_type}
      entry={@selected_entry}
      error={@entry_error}
      form={@entry_form}
      manageable?={can_manage_entry?(@current_scope.actor.id, @selected_entry, @can_manage_types?)}
      metadata_error={@entry_form_media.error}
      metadata_loading?={@entry_form_media.loading?}
      mode={@entry_mode}
      playlist_label={@playlist_label}
      selected_playlist_video_id={@selected_playlist_video_id}
      topic_form={@topic_form}
      topic_options={@topics}
      topic_summaries={@topic_summaries}
      type={@current_type}
    />
    """
  end

  defp render_content(%{live_action: action} = assigns)
       when action in [:index, :entry_new, :entry_show, :entry_edit] do
    ~H"""
    <LibraryToolbar.render
      active_topics={@active_topics}
      active_types={@active_types}
      can_create_entry?={@available_types != []}
      can_manage_types?={@can_manage_types?}
      space_slug={@current_scope.tenant.slug}
      topics={@filter_topics}
      types={@types}
    />

    <div
      class="autogrid [--autogrid-min:14rem] grid gap-4 sm:gap-2 grid-flow-row-dense "
      id="library-entries"
      phx-update="stream"
    >
      <div
        class="hidden rounded-box border border-dashed border-base-content/20 py-16 text-center only:block"
        id="library-entries-empty"
      >
        <div class="font-bold text-xs text-base-content/50">No results found</div>
        <.icon name="hero-magnifying-glass-micro" class="mx-auto size-6 opacity-25" />
      </div>

      <EntryCard.card
        :for={{dom_id, item} <- @streams.entries}
        click_event="entry:show"
        click_testid={"entry-open-#{item.entry.id}"}
        dom_id={dom_id}
        entry={item.entry}
        manageable?={
          can_manage_entry?(
            @current_scope.actor.id,
            item.entry,
            @can_manage_types?
          )
        }
        owned?={item.entry.creator_id == @current_scope.actor.id}
        testid={"library-entry-#{item.entry.id}"}
        topic_summaries={item.topic_summaries}
        type={item.type}
      />
    </div>
    """
  end

  defp render_content(%{live_action: :types} = assigns) do
    ~H"""
    <TypeList.render space_slug={@current_scope.tenant.slug} types={@types} />
    """
  end

  defp render_content(%{live_action: :type_new} = assigns) do
    ~H"""
    <TypeWizard.render
      draft={@wizard_draft}
      form={@type_form}
      import_form={@import_form}
      templates={Schema.built_in_templates()}
    />
    """
  end

  defp render_content(%{live_action: :type_settings} = assigns) do
    ~H"""
    <div class="space-y-4 max-w-[80ch] mx-auto">
      <UI.page_title icon="hero-circle-stack-micro">
        {@current_type.name}
        <:subtitle>Customize type</:subtitle>
      </UI.page_title>

      <SchemaSettings.render
        editing_field={@editing_field}
        field_form={@field_form}
        field_usage_counts={@field_usage_counts}
        type={@current_type}
        type_form={@type_form}
      />

      <PortableSchema.render export_json={Schema.export(@current_type)} />

      <div class="flex items-center justify-end gap-3">
        <span
          :if={@current_type_entry_count > 0}
          class="text-xs text-base-content/45"
          data-testid="type-delete-blocked"
        >
          Used by {@current_type_entry_count} entries
        </span>
        <button
          class="btn btn-sm btn-ghost text-error"
          data-confirm="Delete this type?"
          data-testid="type-delete"
          disabled={@current_type_entry_count > 0}
          phx-click="type:delete"
          type="button"
        >
          <.icon name="hero-trash-micro" /> Delete type
        </button>
      </div>
    </div>
    """
  end

  defp render_content(%{live_action: :topic_matching} = assigns) do
    ~H"""
    <TopicMatching.render
      automatic_topic_matching?={@library_state.automatic_topic_matching?}
      expanded_topic_id={@expanded_topic_id}
      space_slug={@current_scope.tenant.slug}
      topic_views={@topic_views}
    />
    """
  end

  @impl true
  def handle_event("filter:toggle", %{"id" => id, "kind" => "topic"}, socket) do
    topic_ids = toggle_id(socket.assigns.active_topic_ids, id)

    {:noreply,
     push_patch(socket, to: library_path(socket, topic_ids, socket.assigns.active_type_ids))}
  end

  def handle_event("filter:toggle", %{"id" => id, "kind" => "type"}, socket) do
    type_ids = toggle_id(socket.assigns.active_type_ids, id)

    {:noreply,
     push_patch(socket, to: library_path(socket, socket.assigns.active_topic_ids, type_ids))}
  end

  def handle_event("filter:clear", %{"kind" => "topic"}, socket) do
    {:noreply, push_patch(socket, to: library_path(socket, [], socket.assigns.active_type_ids))}
  end

  def handle_event("entry:new", _params, socket) do
    {:noreply, push_patch(socket, to: entry_new_path(socket))}
  end

  def handle_event("entry:type", %{"type_id" => type_id}, socket) do
    case Enum.find(available_types(socket), &(&1.id == type_id)) do
      nil ->
        forbidden_entry_creation(socket)

      type ->
        {:noreply,
         socket
         |> assign(:current_type, type)
         |> assign(:entry_form, entry_form(nil))
         |> assign(:entry_mode, :new)
         |> reset_entry_metadata()}
    end
  end

  def handle_event("entry:change", %{"entry" => params} = event, socket) do
    target = get_in(event, ["_target", Access.at(1)])

    case EntryFormMedia.change(
           socket.assigns.entry_form_media,
           socket.assigns.entry_form.params,
           params,
           target,
           socket.assigns.current_type
         ) do
      {:ok, params, media_state} ->
        {:noreply,
         socket |> assign(:entry_error, nil) |> assign_entry_form_media(params, media_state)}

      {:resolve, params, media, media_state} ->
        {:noreply,
         socket
         |> assign(:entry_error, nil)
         |> resolve_external_media(params, media, media_state)}
    end
  end

  def handle_event("entry:create", %{"entry" => params}, socket) do
    type = socket.assigns.current_type

    case State.create_entry(
           socket.assigns.library_state,
           type,
           socket.assigns.current_scope.actor.id,
           socket.assigns.can_manage_types?,
           params,
           socket.assigns.entry_form_media.external_metadata
         ) do
      {:ok, state, entry} ->
        {:noreply,
         socket
         |> assign(:library_state, state)
         |> refresh_entries()
         |> push_patch(to: entry_path(socket, entry.id))}

      {:error, :forbidden} ->
        forbidden_entry_creation(socket)

      {:error, errors} ->
        {:noreply,
         socket
         |> assign(:entry_form, to_form(params, as: :entry))
         |> put_flash(:error, Enum.join(errors, " · "))}
    end
  end

  def handle_event("entry:show", %{"entry_id" => entry_id}, socket) do
    {:noreply, push_patch(socket, to: entry_path(socket, entry_id))}
  end

  def handle_event("playlist:play", %{"video_id" => video_id}, socket) do
    playlist =
      EntryPresentation.playlist(socket.assigns.current_type, socket.assigns.selected_entry)

    if Enum.any?(playlist.items, &(&1.video_id == video_id)) do
      {:noreply, assign(socket, :selected_playlist_video_id, video_id)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("entry:edit", %{"entry_id" => entry_id}, socket) do
    entry = State.find_entry(socket.assigns.library_state, entry_id)

    if can_manage_entry?(
         socket.assigns.current_scope.actor.id,
         entry,
         socket.assigns.can_manage_types?
       ) do
      {:noreply, push_patch(socket, to: entry_edit_path(socket, entry_id))}
    else
      forbidden_entry(socket)
    end
  end

  def handle_event("entry:update", %{"entry" => params}, socket) do
    entry = socket.assigns.selected_entry
    type = socket.assigns.current_type

    case State.update_entry(
           socket.assigns.library_state,
           type,
           entry && entry.id,
           socket.assigns.current_scope.actor.id,
           socket.assigns.can_manage_types?,
           params,
           socket.assigns.entry_form_media.external_metadata
         ) do
      {:ok, state, entry} ->
        {:noreply,
         socket
         |> assign(:library_state, state)
         |> refresh_entries()
         |> push_patch(to: entry_path(socket, entry.id))}

      {:error, errors} when is_list(errors) ->
        {:noreply,
         socket
         |> assign(:entry_form, to_form(params, as: :entry))
         |> assign(:entry_error, Enum.join(errors, " · "))}

      {:error, reason} when is_binary(reason) ->
        {:noreply, assign(socket, :entry_error, reason)}

      {:error, _reason} ->
        forbidden_entry(socket)
    end
  end

  def handle_event("entry:delete", %{"entry_id" => entry_id}, socket) do
    type = socket.assigns.current_type

    case State.delete_entry(
           socket.assigns.library_state,
           type.id,
           entry_id,
           socket.assigns.current_scope.actor.id,
           socket.assigns.can_manage_types?
         ) do
      {:ok, state, _entry} ->
        {:noreply,
         socket
         |> assign(:library_state, state)
         |> refresh_entries()
         |> push_patch(to: library_path(socket))}

      {:error, reason} when is_binary(reason) ->
        {:noreply, assign(socket, :entry_error, reason)}

      {:error, _reason} ->
        {:noreply, assign(socket, :entry_error, "You cannot delete that Library entry.")}
    end
  end

  def handle_event("topic:add", _params, socket) do
    {:noreply, assign(socket, :topic_form, topic_form())}
  end

  def handle_event("topic:cancel", _params, socket) do
    {:noreply, assign(socket, :topic_form, nil)}
  end

  def handle_event(
        "topic:save",
        %{"entry_topic" => %{"relevancy" => relevancy, "topic_id" => topic_id}},
        socket
      ) do
    entry = socket.assigns.selected_entry
    membership_id = current_membership_id(socket.assigns)
    topic = Enum.find(socket.assigns.topics, &(&1.id == topic_id))

    result =
      if entry && membership_id && topic do
        State.upsert_topic_contribution(
          socket.assigns.library_state,
          entry.id,
          membership_id,
          topic_id,
          relevancy
        )
      else
        {:error, "Choose a topic and relevance from 1 to 10."}
      end

    case result do
      {:ok, state, _contribution} ->
        {:noreply,
         socket
         |> assign(:library_state, state)
         |> assign(:topic_form, nil)
         |> refresh_entries()}

      {:error, message} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("topic:remove", %{"topic_id" => topic_id}, socket) do
    entry = socket.assigns.selected_entry
    membership_id = current_membership_id(socket.assigns)

    case State.remove_topic_contribution(
           socket.assigns.library_state,
           entry.id,
           membership_id,
           topic_id
         ) do
      {:ok, state} ->
        {:noreply, socket |> assign(:library_state, state) |> refresh_entries()}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  def handle_event("topic:dismiss", %{"topic_id" => topic_id}, socket) do
    state =
      State.dismiss_automatic_topic(
        socket.assigns.library_state,
        socket.assigns.selected_entry.id,
        topic_id
      )

    {:noreply, socket |> assign(:library_state, state) |> refresh_entries()}
  end

  def handle_event("matching:toggle", _params, socket) do
    update_matching(socket, &State.toggle_automatic_topic_matching/1)
  end

  def handle_event("matching:expand", %{"topic_id" => topic_id}, socket) do
    expanded_topic_id = if socket.assigns.expanded_topic_id == topic_id, do: nil, else: topic_id
    {:noreply, assign(socket, :expanded_topic_id, expanded_topic_id)}
  end

  def handle_event("matching:rule:toggle", %{"topic_id" => topic_id}, socket) do
    update_matching(socket, &State.toggle_topic_rule(&1, topic_id))
  end

  def handle_event(
        "matching:alias:add",
        %{"topic_alias" => %{"value" => value}, "topic_id" => topic_id},
        socket
      ) do
    update_matching(socket, &State.add_topic_alias(&1, topic_id, value))
  end

  def handle_event(
        "matching:alias:remove",
        %{"alias" => value, "topic_id" => topic_id},
        socket
      ) do
    update_matching(socket, &State.remove_topic_alias(&1, topic_id, value))
  end

  def handle_event("wizard:select", %{"template_id" => template_id}, socket) do
    if socket.assigns.can_manage_types? do
      case Schema.built_in_templates() |> Schema.find_template(template_id) do
        nil ->
          {:noreply, put_flash(socket, :error, "That template is no longer available.")}

        template ->
          draft = Schema.instantiate_template(template)

          {:noreply,
           socket
           |> assign(:type_form, type_create_form(socket.assigns.library_state, draft))
           |> assign(:wizard_draft, draft)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("wizard:back", _params, socket) do
    {:noreply,
     socket
     |> assign(:type_form, type_form(nil))
     |> assign(:wizard_draft, nil)}
  end

  def handle_event("schema:import", %{"schema" => %{"json" => json}}, socket) do
    if socket.assigns.can_manage_types? do
      case Schema.import(json) do
        {:ok, draft} ->
          {:noreply,
           socket
           |> assign(:import_form, to_form(%{"json" => json}, as: :schema))
           |> assign(:type_form, type_create_form(socket.assigns.library_state, draft))
           |> assign(:wizard_draft, draft)}

        {:error, message} ->
          {:noreply,
           socket
           |> assign(:import_form, to_form(%{"json" => json}, as: :schema))
           |> put_flash(:error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("type:create", %{"type" => params}, socket) do
    if socket.assigns.can_manage_types? and socket.assigns.wizard_draft do
      draft = update_type_draft(socket.assigns.wizard_draft, params)

      case State.submit_type_create_form(
             socket.assigns.library_state,
             draft,
             socket.assigns.type_form
           ) do
        {:ok, state, type} ->
          {:noreply,
           socket
           |> assign(:library_state, state)
           |> assign(:wizard_draft, nil)
           |> push_patch(to: type_settings_path(socket, type))}

        {:error, %Phoenix.HTML.Form{} = form} ->
          {:noreply, assign(socket, :type_form, to_form(form))}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("type:validate", %{"type" => params}, socket) do
    if socket.assigns.can_manage_types? and socket.assigns.wizard_draft do
      draft = update_type_draft(socket.assigns.wizard_draft, params)

      form =
        State.validate_type_create_form(
          socket.assigns.library_state,
          draft,
          socket.assigns.type_form
        )

      {:noreply,
       socket
       |> assign(:type_form, to_form(form))
       |> assign(:wizard_draft, draft)}
    else
      forbidden(socket)
    end
  end

  def handle_event("type:update", %{"type" => params}, socket) do
    with true <- socket.assigns.can_manage_types?,
         type when not is_nil(type) <- socket.assigns.current_type,
         {:ok, state, type} <-
           State.submit_type_update_form(
             socket.assigns.library_state,
             type.id,
             socket.assigns.type_form,
             params
           ) do
      {:noreply,
       socket
       |> assign(:current_type, type)
       |> assign(:library_state, state)
       |> assign(:type_form, type_update_form(state, type))}
    else
      {:error, %Phoenix.HTML.Form{} = form} ->
        {:noreply, assign(socket, :type_form, to_form(form))}

      _other ->
        forbidden(socket)
    end
  end

  def handle_event("type:update_validate", %{"type" => params}, socket) do
    if socket.assigns.can_manage_types? and socket.assigns.current_type do
      form = State.validate_type_update_form(socket.assigns.type_form, params)
      {:noreply, assign(socket, :type_form, to_form(form))}
    else
      forbidden(socket)
    end
  end

  def handle_event("type:delete", _params, socket) do
    if socket.assigns.can_manage_types? do
      case State.delete_type(socket.assigns.library_state, socket.assigns.current_type.id) do
        {:ok, state, _type} ->
          {:noreply,
           socket
           |> assign(:library_state, state)
           |> push_patch(to: types_path(socket))}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("field:add", %{"field" => params}, socket) do
    if socket.assigns.can_manage_types? do
      type = socket.assigns.current_type

      case State.add_field(socket.assigns.library_state, type.id, params) do
        {:ok, state, type, _field} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:field_form, field_form(nil))
           |> assign(:library_state, state)
           |> assign_field_usage_counts()}

        {:error, message} ->
          {:noreply, assign_field_error(socket, params, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("field:change", %{"field" => params}, socket) do
    params = Map.merge(socket.assigns.field_form.params, params)
    {:noreply, assign(socket, :field_form, to_form(params, as: :field))}
  end

  def handle_event("field:edit", %{"field_id" => field_id}, socket) do
    if socket.assigns.can_manage_types? do
      case Enum.find(socket.assigns.current_type.fields, &(&1.id == field_id)) do
        nil ->
          {:noreply, put_flash(socket, :error, "That field is no longer available.")}

        field ->
          {:noreply,
           socket
           |> assign(:editing_field, field)
           |> assign(:field_form, field_form(field))
           |> push_event("field:focus-label", %{})}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("field:update", %{"field" => params}, socket) do
    if socket.assigns.can_manage_types? and socket.assigns.editing_field do
      type = socket.assigns.current_type
      field = socket.assigns.editing_field

      case State.update_field(socket.assigns.library_state, type.id, field.id, params) do
        {:ok, state, type, _field} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:editing_field, nil)
           |> assign(:field_form, field_form(nil))
           |> assign(:library_state, state)
           |> assign_field_usage_counts()}

        {:error, message} ->
          {:noreply, assign_field_error(socket, params, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("field:cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_field, nil)
     |> assign(:field_form, field_form(nil))}
  end

  def handle_event("field:delete", %{"field_id" => field_id}, socket) do
    if socket.assigns.can_manage_types? do
      type = socket.assigns.current_type

      case State.delete_field(socket.assigns.library_state, type.id, field_id) do
        {:ok, state, type} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:library_state, state)
           |> assign_field_usage_counts()}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event(
        "field:move",
        %{"direction" => direction, "field_id" => field_id},
        socket
      ) do
    if socket.assigns.can_manage_types? do
      type = socket.assigns.current_type
      direction = if direction == "up", do: :up, else: :down

      case State.move_field(socket.assigns.library_state, type.id, field_id, direction) do
        {:ok, state, type} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:library_state, state)
           |> assign_field_usage_counts()}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("modal:close", _params, socket) do
    {:noreply, push_patch(socket, to: library_path(socket))}
  end

  def handle_event("location_search", %{"q" => query}, socket) do
    case Locations.search(query) do
      {:ok, options} -> {:reply, %{options: options}, socket}
      {:error, _error} -> {:reply, %{options: []}, socket}
    end
  end

  @impl true
  def handle_async({:external_media, request_id}, {:ok, result}, socket) do
    if EntryFormMedia.matching_request?(
         socket.assigns.entry_form_media,
         request_id,
         socket.assigns.entry_form.params
       ) do
      {:noreply, apply_external_media_result(socket, result)}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:external_media, request_id}, {:exit, _reason}, socket) do
    if EntryFormMedia.request_id(socket.assigns.entry_form_media) == request_id do
      {:noreply,
       assign(socket, :entry_form_media, EntryFormMedia.fail(socket.assigns.entry_form_media))}
    else
      {:noreply, socket}
    end
  end

  defp update_matching(socket, update_state) do
    if socket.assigns.can_manage_types? do
      {:noreply,
       socket
       |> assign(:library_state, update_state.(socket.assigns.library_state))
       |> refresh_entries()}
    else
      forbidden(socket)
    end
  end

  defp assign_route_forms(%{assigns: %{live_action: :type_settings}} = socket) do
    socket
    |> assign(:editing_field, nil)
    |> assign(:field_form, field_form(nil))
    |> assign(
      :type_form,
      type_update_form(socket.assigns.library_state, socket.assigns.current_type)
    )
    |> assign(:wizard_draft, nil)
    |> assign_field_usage_counts()
  end

  defp assign_route_forms(%{assigns: %{live_action: :type_new}} = socket), do: socket

  defp assign_route_forms(socket) do
    socket
    |> assign(:editing_field, nil)
    |> assign(:field_form, field_form(nil))
    |> assign(:import_form, to_form(%{"json" => ""}, as: :schema))
    |> assign(:type_form, type_form(nil))
    |> assign(:wizard_draft, nil)
  end

  defp assign_route_entry_form(%{assigns: %{entry_mode: :edit, selected_entry: entry}} = socket) do
    socket
    |> assign(:entry_form, entry_form(entry))
    |> reset_entry_metadata(Map.get(entry, :external_media_metadata))
  end

  defp assign_route_entry_form(%{assigns: %{entry_mode: :new}} = socket) do
    socket
    |> assign(:entry_form, entry_form(nil))
    |> reset_entry_metadata()
  end

  defp assign_route_entry_form(socket), do: reset_entry_metadata(socket)

  defp assign_field_usage_counts(%{assigns: %{current_type: nil}} = socket),
    do: assign(socket, :field_usage_counts, %{})

  defp assign_field_usage_counts(socket) do
    state = socket.assigns.library_state
    type = socket.assigns.current_type

    counts =
      Map.new(type.fields, fn field ->
        {field.id, State.field_usage_count(state, type.id, field)}
      end)

    assign(socket, :field_usage_counts, counts)
  end

  defp refresh_entries(socket) do
    state = socket.assigns.library_state
    current_membership_id = current_membership_id(socket.assigns)

    items =
      state
      |> State.filter_entries(
        socket.assigns.topics,
        socket.assigns.active_topic_ids,
        socket.assigns.active_type_ids
      )
      |> Enum.map(fn entry ->
        type = State.find_type_by_id(state, entry.type_id)

        %{
          entry: entry,
          id: entry.id,
          topic_summaries:
            State.topic_summaries(
              state,
              entry,
              type,
              socket.assigns.topics,
              current_membership_id
            ),
          type: type
        }
      end)

    socket
    |> assign(:entry_list_signature, entry_list_signature(socket))
    |> stream(:entries, items, reset: true)
  end

  defp refresh_entries_if_changed(socket) do
    signature = entry_list_signature(socket)

    if socket.assigns.entry_list_signature == signature do
      socket
    else
      refresh_entries(socket)
    end
  end

  defp entry_list_signature(socket) do
    {
      socket.assigns.library_state,
      socket.assigns.active_topic_ids,
      socket.assigns.active_type_ids,
      socket.assigns.live_action in [:index, :entry_new, :entry_show, :entry_edit]
    }
  end

  defp selected_entry(_state, nil), do: nil
  defp selected_entry(state, entry_id), do: State.find_entry(state, entry_id)

  defp selected_type(state, %{"type_slug" => slug}, _entry), do: State.find_type(state, slug)

  defp selected_type(state, _params, %{type_id: type_id}),
    do: State.find_type_by_id(state, type_id)

  defp selected_type(_state, _params, _entry), do: nil

  defp route_entry_mode(:entry_new, _entry), do: :type_picker
  defp route_entry_mode(:entry_edit, entry) when not is_nil(entry), do: :edit
  defp route_entry_mode(:entry_show, entry) when not is_nil(entry), do: :detail
  defp route_entry_mode(_live_action, _entry), do: nil

  defp filter_ids(nil, _items), do: []

  defp filter_ids(slugs, items) when is_binary(slugs) do
    selected_slugs = String.split(slugs, ",", trim: true)

    items
    |> Enum.filter(&(&1.slug in selected_slugs))
    |> Enum.map(& &1.id)
  end

  defp selected_items(items, selected_ids), do: Enum.filter(items, &(&1.id in selected_ids))

  defp toggle_id(ids, id) do
    if id in ids, do: Enum.reject(ids, &(&1 == id)), else: ids ++ [id]
  end

  defp topic_views(state, topics) do
    Enum.map(topics, fn topic ->
      %{
        count: State.topic_match_count(state, topic, topics),
        rule: State.topic_rule(state, topic.id),
        topic: topic
      }
    end)
  end

  defp selected_entry_topic_summaries(%{selected_entry: nil}, _membership_id), do: []

  defp selected_entry_topic_summaries(assigns, membership_id) do
    State.topic_summaries(
      assigns.library_state,
      assigns.selected_entry,
      assigns.current_type,
      assigns.topics,
      membership_id
    )
  end

  defp current_membership_id(assigns) do
    case assigns.tenant_context do
      %{current_membership: %{id: id}} -> id
      _tenant_context -> nil
    end
  end

  defp available_types(%Phoenix.LiveView.Socket{} = socket) do
    available_types(socket.assigns)
  end

  defp available_types(assigns) do
    Enum.filter(
      assigns.library_state.types,
      &State.can_create_entry?(&1, assigns.can_manage_types?)
    )
  end

  defp load_topics(scope) do
    case Tags.list_space_tags(scope) do
      {:ok, topics} -> topics
      {:error, _error} -> []
    end
  end

  defp type_form(nil) do
    to_form(
      %{"description" => "", "entry_creation_permission" => "", "name" => ""},
      as: :type
    )
  end

  defp type_create_form(state, draft) do
    state
    |> State.type_create_form(draft)
    |> to_form()
  end

  defp type_update_form(state, type) do
    state
    |> State.type_update_form(type)
    |> to_form()
  end

  defp update_type_draft(draft, params) do
    draft
    |> Map.put(:description, Map.get(params, "description", ""))
    |> Map.put(:entry_creation_permission, Map.get(params, "entry_creation_permission"))
    |> Map.put(:name, Map.get(params, "name", ""))
  end

  defp field_form(nil) do
    to_form(
      %{"label" => "", "options" => "", "required" => "false", "type" => "text"},
      as: :field
    )
  end

  defp field_form(field) do
    to_form(
      %{
        "label" => field.label,
        "options" => Enum.join(field.options, ", "),
        "required" => to_string(field.required?),
        "type" => Atom.to_string(field.type)
      },
      as: :field
    )
  end

  defp assign_field_error(socket, params, message) do
    case field_error(message) do
      {field, field_message} ->
        form =
          to_form(params,
            action: :validate,
            as: :field,
            errors: [{field, {field_message, []}}]
          )

        assign(socket, :field_form, form)

      nil ->
        put_flash(socket, :error, message)
    end
  end

  defp field_error("A field label is required."), do: {:label, "is required"}
  defp field_error("Choose a supported field type."), do: {:type, "is not supported"}

  defp field_error("Select fields need at least one option."),
    do: {:options, "must include at least one option"}

  defp field_error("The title field type cannot be changed."),
    do: {:type, "cannot be changed for the title field"}

  defp field_error("The title field is always required."),
    do: {:required, "must remain enabled for the title field"}

  defp field_error("Clear this field from every entry before changing its type."),
    do: {:type, "cannot change while the field contains values"}

  defp field_error("Fill this field in every entry before making it required."),
    do: {:required, "cannot be enabled while some entries are empty"}

  defp field_error("A select option still used by an entry cannot be removed."),
    do: {:options, "cannot remove an option that is still in use"}

  defp field_error(_message), do: nil

  defp entry_form(nil), do: to_form(%{}, as: :entry)
  defp entry_form(entry), do: to_form(entry.values, as: :entry)

  defp resolve_external_media(socket, params, media, media_state) do
    request_id = System.unique_integer([:monotonic, :positive])
    media_state = EntryFormMedia.begin_resolution(media_state, media, request_id)

    socket
    |> assign_entry_form_media(params, media_state)
    |> start_async({:external_media, request_id}, fn -> ExternalMedia.resolve(media) end)
  end

  defp apply_external_media_result(socket, result) do
    {params, media_state} =
      EntryFormMedia.apply_result(
        socket.assigns.entry_form_media,
        socket.assigns.entry_form.params,
        result
      )

    assign_entry_form_media(socket, params, media_state)
  end

  defp assign_entry_form_media(socket, params, media_state) do
    socket
    |> assign(:entry_form, to_form(params, as: :entry))
    |> assign(:entry_form_media, media_state)
  end

  defp reset_entry_metadata(socket, external_media_metadata \\ nil) do
    assign(socket, :entry_form_media, EntryFormMedia.reset(external_media_metadata))
  end

  defp topic_form do
    to_form(%{"relevancy" => "5", "topic_id" => ""}, as: :entry_topic)
  end

  defp can_manage_entry?(actor_id, entry, admin?),
    do: entry && State.can_manage_entry?(entry, actor_id, admin?)

  defp space_admin?(socket) do
    TenantContext.space_admin?(socket.assigns.current_scope, socket.assigns.tenant_context)
  end

  defp forbidden(socket) do
    {:noreply, put_flash(socket, :error, "Only space administrators can do that.")}
  end

  defp forbidden_entry(socket) do
    {:noreply, put_flash(socket, :error, "You can edit or delete only your own entries.")}
  end

  defp forbidden_entry_creation(socket) do
    {:noreply, put_flash(socket, :error, "You cannot add entries to that type.")}
  end

  defp entry_modal_title(:type_picker, _type, _entry), do: "Add entry"
  defp entry_modal_title(:new, type, _entry), do: "Add #{type.name}"

  defp entry_modal_title(_mode, _type, _entry), do: nil

  defp filter_query(socket, topic_ids \\ nil, type_ids \\ nil) do
    topic_ids = topic_ids || socket.assigns.active_topic_ids
    type_ids = type_ids || socket.assigns.active_type_ids

    %{}
    |> maybe_put_filter("topics", selected_slugs(socket.assigns.topics, topic_ids))
    |> maybe_put_filter(
      "types",
      selected_slugs(socket.assigns.library_state.types, type_ids)
    )
  end

  defp selected_slugs(items, selected_ids) do
    items
    |> Enum.filter(&(&1.id in selected_ids))
    |> Enum.map_join(",", & &1.slug)
  end

  defp maybe_put_filter(query, _key, ""), do: query
  defp maybe_put_filter(query, key, value), do: Map.put(query, key, value)

  defp library_path(socket, topic_ids \\ nil, type_ids \\ nil) do
    query = filter_query(socket, topic_ids, type_ids)
    ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries?#{query}"
  end

  defp entry_new_path(socket) do
    query = filter_query(socket)
    ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries/entries/new?#{query}"
  end

  defp entry_path(socket, entry_id) do
    query = filter_query(socket)
    ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries/entries/#{entry_id}?#{query}"
  end

  defp entry_edit_path(socket, entry_id) do
    query = filter_query(socket)
    ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries/entries/#{entry_id}/edit?#{query}"
  end

  defp types_path(socket), do: ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries/types"

  defp type_settings_path(socket, type) do
    ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries/types/#{type.slug}/settings"
  end
end
