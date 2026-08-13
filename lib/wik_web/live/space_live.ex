defmodule WikWeb.SpaceLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Wik.Activity
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalEvent
  alias Wik.Tags.Tag
  alias Wik.Wiki.Page
  alias WikWeb.Components
  alias WikWeb.Components.Activity, as: ActivityComponent
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    space = socket.assigns.current_scope.tenant |> load_space(scope)
    resource_counts = load_resource_counts(scope, space)

    socket =
      socket
      |> assign(activity_query: Activity.entries_query())
      |> assign(form: nil)
      |> assign(resource_counts: resource_counts)
      |> assign(space: space)
      |> assign(editing?: false)

    if connected?(socket), do: Activity.subscribe(space.id)

    {:ok, socket}
  end

  defp init_form(space, scope) do
    space |> Form.for_update(:update, scope: scope) |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.space presences={@presences} scope={@current_scope} view="space">
        <:actions :if={Ash.can?({@space, :update}, @current_scope)}>
          <%= if @editing? do %>
            <UI.button_ok phx-click="toggle_edit_mode" />
          <% else %>
            <UI.button_unlock phx-click="toggle_edit_mode" />
          <% end %>
        </:actions>

        <div class={[
          "grid sm:grid-cols-2 gap-8 max-w-[120ch]"
        ]}>
          <div class="flex-grow">
            <UI.editable_zone
              editing?={@editing?}
              in_place?
              title="Edit space"
              phx-click="update_space_start"
            >
              <div>
                <UI.page_head>
                  <UI.page_title>{@current_scope.tenant |> to_string()}</UI.page_title>
                  <div class={[
                    "flex gap-1",
                    "mt-2",
                    "[&>a]:opacity-70",
                    "[&>a]:hover:opacity-100",
                    "[&>a]:transition",
                    "[&>a]:bg-base-200",
                    "[&>a]:p-4",
                    "[&>a]:rounded",
                    "[&>a]:flex",
                    "[&>a]:justify-center",
                    "[&>a]:relative",
                    "[&>a>*]:-left-1"
                  ]}>
                    <.link navigate={"/#{@space.slug}/wiki"}>
                      <UI.icon_document_with_count count={@resource_counts.documents} />
                    </.link>

                    <.link navigate={"/#{@space.slug}/topics"}>
                      <UI.icon_topic_with_count count={@resource_counts.topics} />
                    </.link>

                    <.link navigate={"/#{@space.slug}/events"}>
                      <UI.icon_event_with_count count={@resource_counts.events} />
                    </.link>

                    <.link navigate={"/#{@space.slug}/members"}>
                      <UI.icon_user_with_count count={@resource_counts.members} />
                    </.link>
                  </div>
                </UI.page_head>

                <div>
                  <UI.panel_title>Description</UI.panel_title>
                  <div class="text-sm bg-base-200/30 p-4 rounded">{@space.description}</div>
                </div>
              </div>
            </UI.editable_zone>
          </div>

          <ActivityComponent.preview
            class={[
              "sm:border-l",
              "sm:border-base-content/10",
              "sm:pl-8"
            ]}
            id="space-activity"
            query={@activity_query}
            scope={@current_scope}
            user_tz={@active_tz}
            view_all_path={~p"/#{@space.slug}/activity"}
          />
        </div>
      </Layouts.space>
    </Layouts.app>

    <Modal.render
      cancel="update_space_cancel"
      cancel_testid="update-space-cancel"
      open?={@form != nil}
      testid="update-space-dialog"
    >
      <Components.Space.form
        :if={Ash.can?({@space, :update}, @current_scope)}
        action_type="update"
        event_submit="space_submit"
        event_validate="space_validate"
        form={@form}
      />
    </Modal.render>
    """
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_info(
        %{topic: "activity_entry:space:" <> space_id},
        %{assigns: %{space: %{id: space_id}}} = socket
      ) do
    {:noreply, Cinder.Refresh.refresh_table(socket, "space-activity-preview-collection")}
  end

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    socket = socket |> assign(editing?: !socket.assigns.editing?)
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_space_start", _params, socket) do
    space = socket.assigns.space
    scope = socket.assigns.current_scope
    socket = socket |> assign(form: init_form(space, scope))
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_space_cancel", _params, socket) do
    socket = socket |> assign(form: nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("space_validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(space_params(params)))}
  end

  @impl true
  def handle_event("space_submit", %{"form" => params}, socket) do
    prev_space = socket.assigns.space

    case socket.assigns.form |> Form.submit(params: space_params(params)) do
      {:ok, space} ->
        if prev_space.slug != space.slug do
          {:noreply, socket |> Phoenix.LiveView.redirect(to: ~p"/#{space.slug}")}
        else
          {:noreply, socket |> assign(space: space, form: nil)}
        end

      {:error, form} ->
        {:noreply,
         socket
         |> assign(form: form)}
    end
  end

  defp load_space(space, scope) do
    Ash.load!(space, [memberships: [:user]], scope: scope)
  end

  defp load_resource_counts(scope, space) do
    %{
      documents: Ash.count!(Page, scope: scope),
      events:
        Ash.count!(EventPublication, scope: scope) + Ash.count!(ExternalEvent, scope: scope),
      members: length(space.memberships),
      topics: Ash.count!(Tag, scope: scope)
    }
  end

  defp space_params(%{"name" => name} = params) do
    Map.put(params, "slug", Utils.Slugify.generate(name))
  end

  defp space_params(params), do: params
end
