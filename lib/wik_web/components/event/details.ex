defmodule WikWeb.Components.Event.Details do
  use WikWeb, :live_component

  alias AshPhoenix.Form
  alias Wik.Events
  alias WikWeb.Components.Event

  @impl true
  def update(%{publication: publication} = assigns, socket) do
    publication_changed? =
      case socket.assigns[:publication] do
        %{id: current_id} -> current_id != publication.id
        _ -> true
      end

    socket =
      socket
      |> assign(assigns)
      |> maybe_reset_state(publication_changed?)
      |> maybe_load_relay_eligibility(publication_changed?)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <Event.event_details
        :if={@mode == :show}
        can_edit?={Ash.can?({@publication.event, :update}, @current_scope)}
        can_relay?={@can_relay?}
        publication={@publication}
        target={@myself}
        user_tz={@user_tz}
      />

      <Event.event_form
        :if={@mode == :edit}
        form={@event_form}
        target={@myself}
        user_tz={@user_tz}
      />

      <Event.relay_form
        :if={@mode == :relay}
        publication={@publication}
        relay_error={@relay_error}
        relay_form={@relay_form}
        relay_target_spaces={@relay_target_spaces}
        target={@myself}
      />
    </div>
    """
  end

  @impl true
  def handle_event("event_detail_edit_start", _params, socket) do
    socket =
      socket
      |> assign(:mode, :edit)
      |> assign(
        :event_form,
        Event.FormState.edit(socket.assigns.publication.event, socket.assigns.current_scope)
      )

    {:noreply, socket}
  end

  def handle_event("event_form_validate", %{"form" => params}, socket) do
    socket =
      socket
      |> assign(:event_form, Event.FormState.validate(socket.assigns.event_form, params))

    {:noreply, socket}
  end

  def handle_event("event_form_submit", %{"form" => params}, socket) do
    socket =
      case Form.submit(socket.assigns.event_form,
             params: params,
             action_opts: [scope: socket.assigns.current_scope]
           ) do
        {:ok, _event} ->
          send(self(), {:event_details, :saved})
          socket

        {:error, form} ->
          assign(socket, :event_form, form)
      end

    {:noreply, socket}
  end

  def handle_event("event_form_cancel", _params, socket) do
    socket =
      socket
      |> assign(:event_form, nil)
      |> assign(:mode, :show)

    {:noreply, socket}
  end

  def handle_event("event_detail_relay_start", _params, socket) do
    socket =
      socket
      |> assign(:mode, :relay)
      |> load_relay_state()

    {:noreply, socket}
  end

  def handle_event("event_relay_cancel", _params, socket) do
    socket =
      socket
      |> assign(:mode, :show)

    {:noreply, socket}
  end

  def handle_event("event_relay_submit", %{"relay" => params}, socket) do
    relay_form = to_form(params, as: :relay)
    relay_note = params["relay_note"]
    target_space_id = params["target_space_id"]

    socket =
      case Enum.find(socket.assigns.relay_target_spaces, &(&1.id == target_space_id)) do
        nil when target_space_id in [nil, ""] ->
          assign(socket, :relay_error, "Select a target space")

        nil ->
          assign(socket, :relay_error, "Could not relay event")

        target_space ->
          case Events.relay_to_space(socket.assigns.publication.event, target_space,
                 scope: socket.assigns.current_scope,
                 relay_note: relay_note
               ) do
            {:ok, _relay_publication} ->
              send(self(), {:event_details, :relay_completed})

              socket
              |> assign(:mode, :show)
              |> assign(:relay_error, nil)
              |> load_relay_eligibility()

            {:error, _error} ->
              assign(socket, :relay_error, "Could not relay event")
          end
      end
      |> assign(:relay_form, relay_form)

    {:noreply, socket}
  end

  defp maybe_reset_state(socket, true) do
    socket
    |> assign(:can_relay?, false)
    |> assign(:event_form, nil)
    |> assign(:mode, :show)
    |> assign(:relay_error, nil)
    |> assign(:relay_form, nil)
    |> assign(:relay_target_spaces, [])
  end

  defp maybe_reset_state(socket, false), do: socket

  defp maybe_load_relay_eligibility(socket, true) do
    load_relay_eligibility(socket)
  end

  defp maybe_load_relay_eligibility(socket, false), do: socket

  defp load_relay_eligibility(socket) do
    case Events.can_relay_event_to_any_space?(
           socket.assigns.publication.event,
           socket.assigns.current_scope
         ) do
      {:ok, can_relay?} ->
        assign(socket, :can_relay?, can_relay?)

      {:error, _error} ->
        assign(socket, :can_relay?, false)
    end
  end

  defp load_relay_state(socket) do
    case Events.list_relay_target_spaces(
           socket.assigns.publication.event,
           socket.assigns.current_scope
         ) do
      {:ok, relay_target_spaces} ->
        socket
        |> assign(:relay_error, nil)
        |> assign(
          :relay_form,
          to_form(%{"relay_note" => "", "target_space_id" => ""}, as: :relay)
        )
        |> assign(:relay_target_spaces, relay_target_spaces)

      {:error, _error} ->
        socket
        |> assign(
          :relay_form,
          to_form(%{"relay_note" => "", "target_space_id" => ""}, as: :relay)
        )
        |> assign(:relay_target_spaces, [])
        |> assign(:relay_error, "Could not load relay targets")
    end
  end
end
