defmodule WikWeb.LibraryPrototypeLive do
  use WikWeb, :live_view

  alias Wik.Locations
  alias Wik.Tags
  alias WikWeb.Components.Modal

  alias WikWeb.LibraryPrototypeLive.Components.{
    EntryCard,
    EntryDetail,
    EntryForm,
    LibraryToolbar,
    PortableSchema,
    SchemaSettings,
    TopicMatching,
    TypeList,
    TypePicker,
    TypeWizard
  }

  alias WikWeb.LibraryPrototypeLive.EntryPresentation
  alias WikWeb.LibraryPrototypeLive.ExternalMedia
  alias WikWeb.LibraryPrototypeLive.Schema
  alias WikWeb.LibraryPrototypeLive.State
  alias WikWeb.TenantContext
  on_mount {WikWeb.LiveUserAuth, :live_scope_required}

  @admin_actions [:topic_matching, :type_new, :type_settings, :types]

  @impl true
  def mount(_params, _session, socket) do
    state = State.new()
    topics = load_topics(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:active_topic_ids, [])
     |> assign(:active_type_ids, [])
     |> assign(:can_manage_types?, space_admin?(socket))
     |> assign(:current_type, nil)
     |> assign(:editing_field, nil)
     |> assign(:entry_autofill_values, %{})
     |> assign(:entry_external_media_metadata, nil)
     |> assign(:entry_form, entry_form(nil))
     |> assign(:entry_list_signature, nil)
     |> assign(:entry_metadata_error, nil)
     |> assign(:entry_metadata_loading?, false)
     |> assign(:entry_metadata_request, nil)
     |> assign(:entry_mode, nil)
     |> assign(:expanded_topic_id, nil)
     |> assign(:field_form, field_form(nil))
     |> assign(:field_usage_counts, %{})
     |> assign(:import_form, to_form(%{"json" => ""}, as: :schema))
     |> assign(:prototype_state, state)
     |> assign(:selected_entry, nil)
     |> assign(:topic_form, nil)
     |> assign(:topics, topics)
     |> assign(:type_form, type_form(nil))
     |> assign(:wizard_draft, nil)
     |> stream(:entries, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state = socket.assigns.prototype_state
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
          |> assign(:selected_entry, selected_entry)
          |> assign(:topic_form, nil)
          |> assign_route_forms()
          |> assign_route_entry_form()
          |> refresh_entries_if_changed()

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    state = assigns.prototype_state
    types = State.types_with_counts(state)
    filter_topics = State.assigned_topics(state, assigns.topics)
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
      cancel="modal:close"
      cancel_testid="library-modal-close"
      open?={@entry_mode != nil}
      testid="library-entry-dialog"
    >
      <:title>
        <div class="flex gap-4 justify-between items-baseline">
          <div class="line-clamp-2">
            {entry_modal_title(@entry_mode, @current_type, @selected_entry)}
          </div>
          <div :if={@current_type} class="grid shrink-0">
            <div class={[
              "badge badge-sm bg-base-300",
              "text-xs small-caps text-base-content/60 whitespace-nowrap"
            ]}>
              {@current_type.name}
            </div>

            <div
              :if={@playlist_label}
              class={[
                "justify-self-end",
                "badge badge-sm",
                "text-xs small-caps text-base-content/60 whitespace-nowrap"
              ]}
              data-testid="entry-playlist-indicator"
            >
              {@playlist_label}
            </div>
          </div>
        </div>
      </:title>

      <TypePicker.render :if={@entry_mode == :type_picker} types={@available_types} />

      <EntryDetail.render
        :if={@entry_mode == :detail && @selected_entry}
        entry={@selected_entry}
        manageable?={can_manage_entry?(@current_scope.actor.id, @selected_entry, @can_manage_types?)}
        topic_form={@topic_form}
        topic_options={@topics}
        topic_summaries={@topic_summaries}
        type={@current_type}
      />
      <EntryForm.render
        :if={@entry_mode in [:new, :edit]}
        form={@entry_form}
        metadata_error={@entry_metadata_error}
        metadata_loading?={@entry_metadata_loading?}
        mode={@entry_mode}
        type={@current_type}
      />
    </Modal.render>
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
      class="autogrid [--autogrid-min:15rem] grid gap-4 sm:gap-2 grid-flow-row-dense "
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

      <article
        :for={{dom_id, item} <- @streams.entries}
        id={dom_id}
        class={[
          "relative grid grid-rows-subgrid text-left group",
          (Enum.any?(item.type.fields, &(&1.type == :media)) && "row-span-3") || "row-span-3",
          "rounded-box overflow-hidden",
          "bg-base-300/60 hover:bg-base-300 hover:scale-103",
          "border border-base-content/10 hover:border-base-content/20",
          "shadow hover:shadow-xl",
          "opacity-90 hover:opacity-100",
          "transition"
        ]}
        data-testid={"library-entry-#{item.entry.id}"}
      >
        <EntryCard.render
          entry={item.entry}
          manageable?={
            can_manage_entry?(
              @current_scope.actor.id,
              item.entry,
              @can_manage_types?
            )
          }
          owned?={item.entry.creator_id == @current_scope.actor.id}
          topic_summaries={item.topic_summaries}
          type={item.type}
        />

        <button
          aria-label={"Open #{EntryPresentation.title(item.type, item.entry)}"}
          class="absolute inset-0 z-10 cursor-pointer rounded-box focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
          data-testid={"entry-open-#{item.entry.id}"}
          phx-click="entry:show"
          phx-value-entry_id={item.entry.id}
          type="button"
        >
        </button>
      </article>
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
      <h1 class="text-2xl flex items-center gap-2 text-base-content/80">
        <.icon name="hero-circle-stack-micro" /> Type settings
      </h1>

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
      automatic_topic_matching?={@prototype_state.automatic_topic_matching?}
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
    previous_media = current_media(socket)
    params = Map.merge(socket.assigns.entry_form.params, params)
    target = get_in(event, ["_target", Access.at(1)])

    socket =
      socket
      |> assign(:entry_form, to_form(params, as: :entry))
      |> track_manual_entry_change(target, params)

    media_changed? = Map.get(params, "media", "") != previous_media

    if media_changed? and external_media_type?(socket.assigns.current_type) do
      {:noreply, resolve_external_media(socket, params)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("entry:create", %{"entry" => params}, socket) do
    type = socket.assigns.current_type

    case State.create_entry(
           socket.assigns.prototype_state,
           type,
           socket.assigns.current_scope.actor.id,
           socket.assigns.can_manage_types?,
           params,
           socket.assigns.entry_external_media_metadata
         ) do
      {:ok, state, entry} ->
        {:noreply,
         socket
         |> assign(:prototype_state, state)
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

  def handle_event("entry:edit", %{"entry_id" => entry_id}, socket) do
    entry = State.find_entry(socket.assigns.prototype_state, entry_id)

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
           socket.assigns.prototype_state,
           type,
           entry && entry.id,
           socket.assigns.current_scope.actor.id,
           socket.assigns.can_manage_types?,
           params,
           socket.assigns.entry_external_media_metadata
         ) do
      {:ok, state, entry} ->
        {:noreply,
         socket
         |> assign(:prototype_state, state)
         |> refresh_entries()
         |> push_patch(to: entry_path(socket, entry.id))}

      {:error, errors} when is_list(errors) ->
        {:noreply,
         socket
         |> assign(:entry_form, to_form(params, as: :entry))
         |> put_flash(:error, Enum.join(errors, " · "))}

      {:error, _reason} ->
        forbidden_entry(socket)
    end
  end

  def handle_event("entry:delete", %{"entry_id" => entry_id}, socket) do
    type = socket.assigns.current_type

    case State.delete_entry(
           socket.assigns.prototype_state,
           type.id,
           entry_id,
           socket.assigns.current_scope.actor.id,
           socket.assigns.can_manage_types?
         ) do
      {:ok, state, _entry} ->
        {:noreply,
         socket
         |> assign(:prototype_state, state)
         |> refresh_entries()
         |> push_patch(to: library_path(socket))}

      {:error, _reason} ->
        forbidden_entry(socket)
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
          socket.assigns.prototype_state,
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
         |> assign(:prototype_state, state)
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
           socket.assigns.prototype_state,
           entry.id,
           membership_id,
           topic_id
         ) do
      {:ok, state} ->
        {:noreply, socket |> assign(:prototype_state, state) |> refresh_entries()}

      {:error, :not_found} ->
        {:noreply, socket}
    end
  end

  def handle_event("topic:dismiss", %{"topic_id" => topic_id}, socket) do
    state =
      State.dismiss_automatic_topic(
        socket.assigns.prototype_state,
        socket.assigns.selected_entry.id,
        topic_id
      )

    {:noreply, socket |> assign(:prototype_state, state) |> refresh_entries()}
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
           |> assign(:type_form, type_form(draft))
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
           |> assign(:type_form, type_form(draft))
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
      draft =
        socket.assigns.wizard_draft
        |> Map.put(:description, Map.get(params, "description", ""))
        |> Map.put(:entry_creation_permission, Map.get(params, "entry_creation_permission"))
        |> Map.put(:name, Map.get(params, "name", ""))

      case State.create_type(socket.assigns.prototype_state, draft) do
        {:ok, state, type} ->
          {:noreply,
           socket
           |> assign(:prototype_state, state)
           |> assign(:wizard_draft, nil)
           |> push_patch(to: type_settings_path(socket, type))}

        {:error, message} ->
          {:noreply,
           socket
           |> assign(:type_form, to_form(params, as: :type))
           |> put_flash(:error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("type:update", %{"type" => params}, socket) do
    with true <- socket.assigns.can_manage_types?,
         type when not is_nil(type) <- socket.assigns.current_type,
         {:ok, state, type} <-
           State.update_type(socket.assigns.prototype_state, type.id, params) do
      {:noreply,
       socket
       |> assign(:current_type, type)
       |> assign(:prototype_state, state)
       |> assign(:type_form, type_form(type))}
    else
      {:error, message} -> {:noreply, put_flash(socket, :error, message)}
      _other -> forbidden(socket)
    end
  end

  def handle_event(
        "type:entry_creation_permission:update",
        %{"permission" => permission},
        socket
      ) do
    type = socket.assigns.current_type

    if socket.assigns.can_manage_types? and type do
      case State.update_entry_creation_permission(
             socket.assigns.prototype_state,
             type.id,
             permission
           ) do
        {:ok, state, type} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:prototype_state, state)}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("type:delete", _params, socket) do
    if socket.assigns.can_manage_types? do
      case State.delete_type(socket.assigns.prototype_state, socket.assigns.current_type.id) do
        {:ok, state, _type} ->
          {:noreply,
           socket
           |> assign(:prototype_state, state)
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

      case State.add_field(socket.assigns.prototype_state, type.id, params) do
        {:ok, state, type, _field} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:field_form, field_form(nil))
           |> assign(:prototype_state, state)
           |> assign_field_usage_counts()}

        {:error, message} ->
          {:noreply,
           socket
           |> assign(:field_form, to_form(params, as: :field))
           |> put_flash(:error, message)}
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
           |> assign(:field_form, field_form(field))}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("field:update", %{"field" => params}, socket) do
    if socket.assigns.can_manage_types? and socket.assigns.editing_field do
      type = socket.assigns.current_type
      field = socket.assigns.editing_field

      case State.update_field(socket.assigns.prototype_state, type.id, field.id, params) do
        {:ok, state, type, _field} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:editing_field, nil)
           |> assign(:field_form, field_form(nil))
           |> assign(:prototype_state, state)
           |> assign_field_usage_counts()}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
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

      case State.delete_field(socket.assigns.prototype_state, type.id, field_id) do
        {:ok, state, type} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:prototype_state, state)
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

      case State.move_field(socket.assigns.prototype_state, type.id, field_id, direction) do
        {:ok, state, type} ->
          {:noreply,
           socket
           |> assign(:current_type, type)
           |> assign(:prototype_state, state)
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
    request = socket.assigns.entry_metadata_request

    if request && request.id == request_id && current_media(socket) == request.url do
      {:noreply, apply_external_media_result(socket, result)}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:external_media, request_id}, {:exit, _reason}, socket) do
    request = socket.assigns.entry_metadata_request

    if request && request.id == request_id do
      {:noreply,
       socket
       |> assign(:entry_metadata_error, "Details couldn't be loaded")
       |> assign(:entry_metadata_loading?, false)
       |> assign(:entry_metadata_request, nil)}
    else
      {:noreply, socket}
    end
  end

  defp update_matching(socket, update_state) do
    if socket.assigns.can_manage_types? do
      {:noreply,
       socket
       |> assign(:prototype_state, update_state.(socket.assigns.prototype_state))
       |> refresh_entries()}
    else
      forbidden(socket)
    end
  end

  defp assign_route_forms(%{assigns: %{live_action: :type_settings}} = socket) do
    socket
    |> assign(:editing_field, nil)
    |> assign(:field_form, field_form(nil))
    |> assign(:type_form, type_form(socket.assigns.current_type))
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
    state = socket.assigns.prototype_state
    type = socket.assigns.current_type

    counts =
      Map.new(type.fields, fn field ->
        {field.id, State.field_usage_count(state, type.id, field)}
      end)

    assign(socket, :field_usage_counts, counts)
  end

  defp refresh_entries(socket) do
    state = socket.assigns.prototype_state
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
      socket.assigns.prototype_state,
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
      assigns.prototype_state,
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
      assigns.prototype_state.types,
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

  defp type_form(type) do
    to_form(
      %{
        "description" => type.description,
        "entry_creation_permission" =>
          type |> Map.get(:entry_creation_permission, "") |> to_string(),
        "name" => type.name
      },
      as: :type
    )
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

  defp entry_form(nil), do: to_form(%{}, as: :entry)
  defp entry_form(entry), do: to_form(entry.values, as: :entry)

  defp resolve_external_media(socket, params) do
    params = clear_previous_autofill(params, socket.assigns.entry_autofill_values)
    media = params |> Map.get("media", "") |> String.trim()

    socket =
      socket
      |> assign(:entry_autofill_values, %{})
      |> assign(:entry_external_media_metadata, nil)
      |> assign(:entry_form, to_form(params, as: :entry))
      |> assign(:entry_metadata_error, nil)
      |> assign(:entry_metadata_loading?, false)
      |> assign(:entry_metadata_request, nil)

    if media == "" do
      socket
    else
      request_id = System.unique_integer([:monotonic, :positive])

      socket
      |> assign(:entry_metadata_loading?, true)
      |> assign(:entry_metadata_request, %{id: request_id, url: media})
      |> start_async({:external_media, request_id}, fn -> ExternalMedia.resolve(media) end)
    end
  end

  defp apply_external_media_result(socket, {:ok, metadata}) do
    {params, autofill_values} =
      Enum.reduce(
        [creator: :creator, duration: :duration, notes: :description, title: :title],
        {socket.assigns.entry_form.params, %{}},
        fn {field, metadata_key}, acc ->
          put_autofill_value(acc, Atom.to_string(field), Map.get(metadata, metadata_key))
        end
      )

    socket
    |> assign(:entry_autofill_values, autofill_values)
    |> assign(
      :entry_external_media_metadata,
      external_media_metadata(metadata, current_media(socket))
    )
    |> assign(:entry_form, to_form(params, as: :entry))
    |> assign(:entry_metadata_error, nil)
    |> assign(:entry_metadata_loading?, false)
    |> assign(:entry_metadata_request, nil)
  end

  defp apply_external_media_result(socket, {:error, :unsupported_provider}) do
    socket
    |> assign(:entry_metadata_loading?, false)
    |> assign(:entry_metadata_request, nil)
  end

  defp apply_external_media_result(socket, {:error, _reason}) do
    socket
    |> assign(:entry_metadata_error, "Details couldn't be loaded")
    |> assign(:entry_metadata_loading?, false)
    |> assign(:entry_metadata_request, nil)
  end

  defp put_autofill_value({params, autofill_values}, _key, nil),
    do: {params, autofill_values}

  defp put_autofill_value({params, autofill_values}, key, value) do
    current_value = Map.get(params, key, "")

    if Schema.blank_value?(current_value) do
      {Map.put(params, key, value), Map.put(autofill_values, key, value)}
    else
      {params, autofill_values}
    end
  end

  defp clear_previous_autofill(params, autofill_values) do
    Enum.reduce(autofill_values, params, fn {key, value}, params ->
      if Map.get(params, key) == value, do: Map.put(params, key, ""), else: params
    end)
  end

  defp track_manual_entry_change(socket, key, params) when is_binary(key) do
    case Map.fetch(socket.assigns.entry_autofill_values, key) do
      {:ok, autofill_value} ->
        if autofill_value == Map.get(params, key) do
          socket
        else
          assign(
            socket,
            :entry_autofill_values,
            Map.delete(socket.assigns.entry_autofill_values, key)
          )
        end

      _value ->
        socket
    end
  end

  defp track_manual_entry_change(socket, _key, _params), do: socket

  defp current_media(socket) do
    socket.assigns.entry_form.params |> Map.get("media", "") |> String.trim()
  end

  defp external_media_type?(%{slug: "external-media"}), do: true
  defp external_media_type?(_type), do: false

  defp external_media_metadata(
         %{provider: :youtube, kind: :playlist} = metadata,
         source_url
       ) do
    %{
      item_count: Map.get(metadata, :item_count),
      kind: :playlist,
      playlist_items: Map.get(metadata, :playlist_items, []),
      provider: :youtube,
      source_url: source_url,
      thumbnail_url: Map.get(metadata, :thumbnail_url)
    }
  end

  defp external_media_metadata(_metadata, _source_url), do: nil

  defp reset_entry_metadata(socket, external_media_metadata \\ nil) do
    socket
    |> assign(:entry_autofill_values, %{})
    |> assign(:entry_external_media_metadata, external_media_metadata)
    |> assign(:entry_metadata_error, nil)
    |> assign(:entry_metadata_loading?, false)
    |> assign(:entry_metadata_request, nil)
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
  defp entry_modal_title(:edit, type, entry), do: "Edit #{EntryPresentation.title(type, entry)}"
  defp entry_modal_title(:detail, type, entry), do: EntryPresentation.title(type, entry)
  defp entry_modal_title(_mode, _type, _entry), do: nil

  defp filter_query(socket, topic_ids \\ nil, type_ids \\ nil) do
    topic_ids = topic_ids || socket.assigns.active_topic_ids
    type_ids = type_ids || socket.assigns.active_type_ids

    %{}
    |> maybe_put_filter("topics", selected_slugs(socket.assigns.topics, topic_ids))
    |> maybe_put_filter(
      "types",
      selected_slugs(socket.assigns.prototype_state.types, type_ids)
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
