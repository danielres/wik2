defmodule WikWeb.LibraryPrototypeLive do
  use WikWeb, :live_view

  alias Wik.Locations
  alias WikWeb.Components.Modal
  alias WikWeb.LibraryPrototypeLive.Components
  alias WikWeb.LibraryPrototypeLive.Schema
  alias WikWeb.LibraryPrototypeLive.State
  alias WikWeb.TenantContext

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}

  @admin_actions [:new, :settings]

  @impl true
  def mount(_params, _session, socket) do
    state = State.new()

    socket =
      socket
      |> assign(:can_manage_collections?, space_admin?(socket))
      |> assign(:collection_form, collection_form(nil))
      |> assign(:current_collection, State.default_collection(state))
      |> assign(:editing_field, nil)
      |> assign(:entry_form, entry_form(nil))
      |> assign(:entry_mode, nil)
      |> assign(:field_form, field_form(nil))
      |> assign(:field_usage_counts, %{})
      |> assign(:import_form, to_form(%{"json" => ""}, as: :schema))
      |> assign(:prototype_state, state)
      |> assign(:selected_entry, nil)
      |> assign(:wizard_draft, nil)
      |> stream(:collection_cards, State.navigation(state))
      |> stream(:entries, [])

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    state = socket.assigns.prototype_state
    collection = selected_collection(state, params, socket.assigns.live_action)
    selected_entry = selected_entry(state, collection, params["entry_id"] || params["entry"])
    entry_mode = route_entry_mode(socket.assigns.live_action, selected_entry, params)

    cond do
      socket.assigns.live_action in @admin_actions and not socket.assigns.can_manage_collections? ->
        socket =
          socket
          |> put_flash(:error, "Only space administrators can manage collection schemas.")
          |> push_patch(to: library_path(socket))

        {:noreply, socket}

      socket.assigns.live_action == :entry_new and
          not can_create_entry?(collection, socket.assigns.can_manage_collections?) ->
        socket =
          socket
          |> put_flash(:error, "Only space owners and admins can add entries to this collection.")
          |> push_patch(to: collection_path(socket, collection))

        {:noreply, socket}

      socket.assigns.live_action == :entry_edit and
          not can_manage_entry?(
            socket.assigns.current_scope.actor.id,
            selected_entry,
            socket.assigns.can_manage_collections?
          ) ->
        socket =
          socket
          |> put_flash(:error, "You can edit or delete only your own entries.")
          |> push_patch(to: collection_path(socket, collection))

        {:noreply, socket}

      true ->
        socket =
          socket
          |> assign(:current_collection, collection)
          |> assign(:selected_entry, selected_entry)
          |> assign(:entry_mode, entry_mode)
          |> assign_route_forms()
          |> assign_route_entry_form()
          |> refresh_collections()
          |> refresh_entries()

        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :collections, State.navigation(assigns.prototype_state))

    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      scope={@current_scope}
      tenant_context={@tenant_context}
    >
      <Layouts.space scope={@current_scope} view="libraries">
        <div class="space-y-6" data-testid="library-prototype-page">
          <div class="grid gap-7 md:grid-cols-[13rem_minmax(0,1fr)]">
            <aside class="md:sticky md:top-20 md:self-start">
              <Components.collection_navigation
                can_manage_collections?={@can_manage_collections?}
                collections={@collections}
                current_collection={@current_collection}
                space_slug={@current_scope.tenant.slug}
                live_action={@live_action}
                current_scope={@current_scope}
              />
            </aside>

            <main class="min-w-0 max-w-[80ch]">
              <%= case @live_action do %>
                <% :index -> %>
                  <div class="space-y-6">
                    <div
                      class="grid gap-1"
                      id="library-collections"
                      phx-update="stream"
                    >
                      <div id="library-collections-empty" class="hidden only:block">
                        No collections yet.
                      </div>
                      <Components.collection_card
                        :for={{dom_id, collection} <- @streams.collection_cards}
                        collection={collection}
                        id={dom_id}
                        space_slug={@current_scope.tenant.slug}
                      />
                    </div>
                  </div>
                <% :new -> %>
                  <Components.collection_wizard
                    draft={@wizard_draft}
                    form={@collection_form}
                    import_form={@import_form}
                    templates={Schema.built_in_templates()}
                  />
                <% :settings -> %>
                  <div class="space-y-6">
                    <Components.schema_settings
                      collection={@current_collection}
                      collection_form={@collection_form}
                      editing_field={@editing_field}
                      field_form={@field_form}
                      field_usage_counts={@field_usage_counts}
                    />
                    <Components.portable_schema export_json={Schema.export(@current_collection)} />
                    <div class="flex justify-end rounded-box border border-error/15 bg-error/5 p-4">
                      <button
                        class="btn btn-sm btn-ghost text-error"
                        data-confirm="Delete this collection and all of its entries?"
                        data-testid="collection-delete"
                        phx-click="collection:delete"
                        type="button"
                      >
                        <.icon name="hero-trash-micro" /> Delete collection
                      </button>
                    </div>
                  </div>
                <% _show -> %>
                  <div class="space-y-6">
                    <header class="flex flex-wrap items-end justify-between gap-4">
                      <div>
                        <div class="flex items-center gap-2">
                          <h1 id="collection-title" class="text-3xl font-bold tracking-tight">
                            {@current_collection.name}
                          </h1>

                          <.link
                            :if={@can_manage_collections?}
                            aria-label={"Edit #{@current_collection.name} collection"}
                            class={["btn btn-ghost btn-accent", "btn-circle btn-sm"]}
                            data-testid="collection-settings-open"
                            patch={
                              ~p"/#{@current_scope.tenant.slug}/libraries/#{@current_collection.slug}/settings"
                            }
                          >
                            <.icon name="hero-pencil-micro" />
                          </.link>
                        </div>
                        <p class="text-sm leading-relaxed text-base-content/55">
                          {@current_collection.description}
                        </p>
                      </div>
                    </header>

                    <div class="flex justify-end">
                      <button
                        :if={can_create_entry?(@current_collection, @can_manage_collections?)}
                        class={[
                          "btn btn-xs",
                          if(@current_collection.entry_creation_permission == :admins,
                            do: "btn-accent",
                            else: "btn-soft"
                          )
                        ]}
                        data-testid="entry-create-open"
                        phx-click="entry:new"
                        type="button"
                      >
                        <.icon name="hero-plus-micro" /> Add entry
                      </button>
                    </div>
                    <div class="grid gap-3" id="library-entries" phx-update="stream">
                      <div
                        class="hidden rounded-box border border-dashed border-base-content/20 py-16 text-center only:block"
                        id="library-entries-empty"
                      >
                        <.icon name="hero-inbox-micro" class="mx-auto mb-3 size-8 opacity-25" />
                        <p class="font-bold text-base-content/60">No entries yet</p>
                        <p class="mt-1 text-sm text-base-content/40">
                          Add the first useful reference.
                        </p>
                      </div>
                      <div :for={{dom_id, entry} <- @streams.entries} id={dom_id}>
                        <Components.entry_card
                          collection={@current_collection}
                          entry={entry}
                          manageable?={
                            can_manage_entry?(
                              @current_scope.actor.id,
                              entry,
                              @can_manage_collections?
                            )
                          }
                          owned?={entry.creator_id == @current_scope.actor.id}
                        />
                      </div>
                    </div>
                  </div>
              <% end %>
            </main>
          </div>
        </div>
      </Layouts.space>
    </Layouts.app>

    <Modal.render
      cancel="modal:close"
      cancel_testid="library-modal-close"
      open?={@entry_mode != nil}
      testid="library-entry-dialog"
    >
      <:title>{entry_modal_title(@entry_mode, @current_collection, @selected_entry)}</:title>

      <Components.entry_detail
        :if={@entry_mode == :detail && @selected_entry}
        collection={@current_collection}
        entry={@selected_entry}
        manageable?={
          can_manage_entry?(@current_scope.actor.id, @selected_entry, @can_manage_collections?)
        }
      />
      <Components.entry_form
        :if={@entry_mode in [:new, :edit]}
        collection={@current_collection}
        form={@entry_form}
        mode={@entry_mode}
      />
    </Modal.render>
    """
  end

  @impl true
  def handle_event("wizard:select", %{"template_id" => template_id}, socket) do
    if socket.assigns.can_manage_collections? do
      case Schema.built_in_templates() |> Schema.find_template(template_id) do
        nil ->
          {:noreply, put_flash(socket, :error, "That template is no longer available.")}

        template ->
          draft = Schema.instantiate_template(template)

          {:noreply,
           socket
           |> assign(:wizard_draft, draft)
           |> assign(:collection_form, collection_form(draft))}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("wizard:back", _params, socket) do
    {:noreply,
     socket
     |> assign(:wizard_draft, nil)
     |> assign(:collection_form, collection_form(nil))}
  end

  def handle_event("schema:import", %{"schema" => %{"json" => json}}, socket) do
    if socket.assigns.can_manage_collections? do
      case Schema.import(json) do
        {:ok, draft} ->
          {:noreply,
           socket
           |> assign(:wizard_draft, draft)
           |> assign(:collection_form, collection_form(draft))
           |> assign(:import_form, to_form(%{"json" => json}, as: :schema))}

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

  def handle_event("collection:create", %{"collection" => params}, socket) do
    if socket.assigns.can_manage_collections? and socket.assigns.wizard_draft do
      draft =
        socket.assigns.wizard_draft
        |> Map.put(:description, Map.get(params, "description", ""))
        |> Map.put(:entry_creation_permission, Map.get(params, "entry_creation_permission"))
        |> Map.put(:name, Map.get(params, "name", ""))

      case State.create_collection(socket.assigns.prototype_state, draft) do
        {:ok, state, collection} ->
          socket =
            socket
            |> assign(:prototype_state, state)
            |> assign(:wizard_draft, nil)

          {:noreply, push_patch(socket, to: collection_path(socket, collection))}

        {:error, message} ->
          {:noreply,
           socket
           |> assign(:collection_form, to_form(params, as: :collection))
           |> put_flash(:error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("collection:update", %{"collection" => params}, socket) do
    if socket.assigns.can_manage_collections? do
      collection = socket.assigns.current_collection

      case State.update_collection(socket.assigns.prototype_state, collection.id, params) do
        {:ok, state, collection} ->
          {:noreply,
           socket
           |> assign(:prototype_state, state)
           |> assign(:current_collection, collection)
           |> assign(:collection_form, collection_form(collection))
           |> refresh_collections()
           |> put_flash(:info, "Collection details saved.")}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event(
        "collection:entry_creation_permission:update",
        %{"permission" => permission},
        socket
      ) do
    if socket.assigns.can_manage_collections? do
      collection = socket.assigns.current_collection

      case State.update_entry_creation_permission(
             socket.assigns.prototype_state,
             collection.id,
             permission
           ) do
        {:ok, state, collection} ->
          {:noreply,
           socket
           |> assign(:prototype_state, state)
           |> assign(:current_collection, collection)
           |> refresh_collections()}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("collection:delete", _params, socket) do
    if socket.assigns.can_manage_collections? do
      state =
        State.delete_collection(
          socket.assigns.prototype_state,
          socket.assigns.current_collection.id
        )

      {:noreply,
       socket |> assign(:prototype_state, state) |> push_patch(to: library_path(socket))}
    else
      forbidden(socket)
    end
  end

  def handle_event("field:add", %{"field" => params}, socket) do
    if socket.assigns.can_manage_collections? do
      collection = socket.assigns.current_collection

      case State.add_field(socket.assigns.prototype_state, collection.id, params) do
        {:ok, state, collection, _field} ->
          {:noreply,
           socket
           |> assign(:prototype_state, state)
           |> assign(:current_collection, collection)
           |> assign(:field_form, field_form(nil))
           |> refresh_collections()}

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
    if socket.assigns.can_manage_collections? do
      case Enum.find(socket.assigns.current_collection.fields, &(&1.id == field_id)) do
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
    if socket.assigns.can_manage_collections? and socket.assigns.editing_field do
      collection = socket.assigns.current_collection
      field = socket.assigns.editing_field

      case State.update_field(socket.assigns.prototype_state, collection.id, field.id, params) do
        {:ok, state, collection, _field} ->
          {:noreply,
           socket
           |> assign(:prototype_state, state)
           |> assign(:current_collection, collection)
           |> assign(:editing_field, nil)
           |> assign(:field_form, field_form(nil))
           |> refresh_entries()}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("field:cancel", _params, socket) do
    {:noreply, socket |> assign(:editing_field, nil) |> assign(:field_form, field_form(nil))}
  end

  def handle_event("field:delete", %{"field_id" => field_id}, socket) do
    if socket.assigns.can_manage_collections? do
      collection = socket.assigns.current_collection

      case State.delete_field(socket.assigns.prototype_state, collection.id, field_id) do
        {:ok, state, collection} ->
          {:noreply,
           socket
           |> assign(:prototype_state, state)
           |> assign(:current_collection, collection)
           |> refresh_entries()}

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
    if socket.assigns.can_manage_collections? do
      collection = socket.assigns.current_collection
      direction = if direction == "up", do: :up, else: :down

      case State.move_field(socket.assigns.prototype_state, collection.id, field_id, direction) do
        {:ok, state, collection} ->
          {:noreply,
           socket
           |> assign(:prototype_state, state)
           |> assign(:current_collection, collection)
           |> refresh_entries()}

        {:error, message} ->
          {:noreply, put_flash(socket, :error, message)}
      end
    else
      forbidden(socket)
    end
  end

  def handle_event("entry:new", _params, socket) do
    if can_create_entry?(
         socket.assigns.current_collection,
         socket.assigns.can_manage_collections?
       ) do
      {:noreply, push_patch(socket, to: entry_new_path(socket))}
    else
      forbidden_entry_creation(socket)
    end
  end

  def handle_event("entry:create", %{"entry" => params}, socket) do
    actor_id = socket.assigns.current_scope.actor.id
    collection = socket.assigns.current_collection

    case State.create_entry(
           socket.assigns.prototype_state,
           collection,
           actor_id,
           socket.assigns.can_manage_collections?,
           params
         ) do
      {:ok, state, entry} ->
        {:noreply,
         socket
         |> assign(:prototype_state, state)
         |> stream_insert(:entries, entry, at: 0)
         |> refresh_collections()
         |> push_patch(to: collection_path(socket, collection))}

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
    actor_id = socket.assigns.current_scope.actor.id

    if entry &&
         State.can_manage_entry?(entry, actor_id, socket.assigns.can_manage_collections?) do
      {:noreply, push_patch(socket, to: entry_edit_path(socket, entry))}
    else
      forbidden_entry(socket)
    end
  end

  def handle_event("entry:update", %{"entry" => params}, socket) do
    entry = socket.assigns.selected_entry
    actor_id = socket.assigns.current_scope.actor.id
    collection = socket.assigns.current_collection

    result =
      State.update_entry(
        socket.assigns.prototype_state,
        collection,
        entry && entry.id,
        actor_id,
        socket.assigns.can_manage_collections?,
        params
      )

    case result do
      {:ok, state, entry} ->
        {:noreply,
         socket
         |> assign(:prototype_state, state)
         |> stream_insert(:entries, entry)
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
    actor_id = socket.assigns.current_scope.actor.id
    collection = socket.assigns.current_collection

    case State.delete_entry(
           socket.assigns.prototype_state,
           collection.id,
           entry_id,
           actor_id,
           socket.assigns.can_manage_collections?
         ) do
      {:ok, state, entry} ->
        {:noreply,
         socket
         |> assign(:prototype_state, state)
         |> assign(:entry_mode, nil)
         |> assign(:selected_entry, nil)
         |> stream_delete(:entries, entry)
         |> refresh_collections()
         |> push_patch(to: collection_path(socket, collection))}

      {:error, _reason} ->
        forbidden_entry(socket)
    end
  end

  def handle_event("modal:close", _params, socket) do
    socket = socket |> assign(:entry_mode, nil) |> assign(:selected_entry, nil)

    if socket.assigns.current_collection do
      {:noreply,
       push_patch(socket, to: collection_path(socket, socket.assigns.current_collection))}
    else
      {:noreply, socket}
    end
  end

  def handle_event("location_search", %{"q" => query}, socket) do
    case Locations.search(query) do
      {:ok, options} -> {:reply, %{options: options}, socket}
      {:error, _error} -> {:reply, %{options: []}, socket}
    end
  end

  defp assign_route_forms(socket) do
    collection = socket.assigns.current_collection

    socket
    |> assign(:collection_form, collection_form(collection))
    |> assign(:editing_field, nil)
    |> assign(:field_form, field_form(nil))
    |> maybe_clear_wizard()
  end

  defp assign_route_entry_form(%{assigns: %{entry_mode: :edit, selected_entry: entry}} = socket) do
    assign(socket, :entry_form, entry_form(entry))
  end

  defp assign_route_entry_form(%{assigns: %{entry_mode: :new}} = socket) do
    assign(socket, :entry_form, entry_form(nil))
  end

  defp assign_route_entry_form(socket), do: socket

  defp maybe_clear_wizard(%{assigns: %{live_action: :new}} = socket), do: socket

  defp maybe_clear_wizard(socket) do
    socket
    |> assign(:wizard_draft, nil)
    |> assign(:import_form, to_form(%{"json" => ""}, as: :schema))
  end

  defp refresh_collections(socket) do
    stream(socket, :collection_cards, State.navigation(socket.assigns.prototype_state),
      reset: true
    )
  end

  defp refresh_entries(%{assigns: %{current_collection: nil}} = socket) do
    socket
    |> assign(:field_usage_counts, %{})
    |> stream(:entries, [], reset: true)
  end

  defp refresh_entries(socket) do
    state = socket.assigns.prototype_state
    collection = socket.assigns.current_collection

    entries =
      State.entries_for(state, collection.id)

    field_usage_counts =
      Map.new(collection.fields, fn field ->
        {field.id, State.field_usage_count(state, collection.id, field)}
      end)

    socket
    |> assign(:field_usage_counts, field_usage_counts)
    |> stream(:entries, entries, reset: true)
  end

  defp selected_collection(state, params, live_action) do
    case {live_action, params["collection_slug"]} do
      {:index, _slug} -> nil
      {:new, _slug} -> nil
      {_action, nil} -> State.default_collection(state)
      {_action, slug} -> State.find_collection(state, slug) || State.default_collection(state)
    end
  end

  defp selected_entry(_state, nil, _entry_id), do: nil
  defp selected_entry(_state, _collection, nil), do: nil

  defp selected_entry(state, collection, entry_id) do
    case State.find_entry(state, entry_id) do
      %{collection_id: collection_id} = entry when collection_id == collection.id -> entry
      _entry -> nil
    end
  end

  defp route_entry_mode(:entry_new, _entry, _params), do: :new
  defp route_entry_mode(:entry_edit, entry, _params) when not is_nil(entry), do: :edit
  defp route_entry_mode(:entry_show, entry, _params) when not is_nil(entry), do: :detail
  defp route_entry_mode(:show, entry, %{"entry" => _entry_id}) when not is_nil(entry), do: :detail
  defp route_entry_mode(_live_action, _entry, _params), do: nil

  defp collection_form(nil) do
    to_form(
      %{"description" => "", "entry_creation_permission" => "", "name" => ""},
      as: :collection
    )
  end

  defp collection_form(collection) do
    to_form(
      %{
        "description" => collection.description,
        "entry_creation_permission" =>
          collection |> Map.get(:entry_creation_permission, "") |> to_string(),
        "name" => collection.name
      },
      as: :collection
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

  defp can_manage_entry?(actor_id, entry, admin?) do
    entry && State.can_manage_entry?(entry, actor_id, admin?)
  end

  defp can_create_entry?(nil, _admin?), do: false
  defp can_create_entry?(collection, admin?), do: State.can_create_entry?(collection, admin?)

  defp space_admin?(socket) do
    TenantContext.space_admin?(socket.assigns.current_scope, socket.assigns.tenant_context)
  end

  defp forbidden(socket) do
    {:noreply, put_flash(socket, :error, "Only space administrators can do that.")}
  end

  defp forbidden_entry(socket) do
    {:noreply,
     socket
     |> assign(:entry_mode, nil)
     |> assign(:selected_entry, nil)
     |> put_flash(:error, "You can edit or delete only your own entries.")}
  end

  defp forbidden_entry_creation(socket) do
    {:noreply,
     put_flash(socket, :error, "Only space owners and admins can add entries to this collection.")}
  end

  defp entry_modal_title(:new, collection, _entry), do: "Add to #{collection.name}"

  defp entry_modal_title(:edit, collection, entry),
    do: "Edit #{Components.entry_title(collection, entry)}"

  defp entry_modal_title(:detail, collection, entry),
    do: Components.entry_title(collection, entry)

  defp entry_modal_title(_mode, _collection, _entry), do: nil

  defp entry_path(socket, entry_id) do
    collection = socket.assigns.current_collection

    ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries/#{collection.slug}/entries/#{entry_id}"
  end

  defp entry_new_path(socket) do
    collection = socket.assigns.current_collection
    ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries/#{collection.slug}/entries/new"
  end

  defp entry_edit_path(socket, entry) do
    collection = socket.assigns.current_collection

    ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries/#{collection.slug}/entries/#{entry.id}/edit"
  end

  defp collection_path(socket, collection) do
    collection_path_for(socket.assigns.current_scope.tenant.slug, collection)
  end

  defp collection_path_for(space_slug, collection) do
    ~p"/#{space_slug}/libraries/#{collection.slug}"
  end

  defp library_path(socket), do: ~p"/#{socket.assigns.current_scope.tenant.slug}/libraries"
end
