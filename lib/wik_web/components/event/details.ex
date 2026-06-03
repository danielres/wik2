defmodule WikWeb.Components.Event.Details do
  use WikWeb, :live_component

  alias AshPhoenix.Form
  alias Wik.Accounts
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
      |> maybe_load_author_membership(publication_changed?)
      |> maybe_load_relayer_membership(publication_changed?)
      |> maybe_load_origin_space_visibility(publication_changed?)
      |> maybe_load_relay_eligibility(publication_changed?)
      |> maybe_load_participations(publication_changed?)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <Event.event_details
        :if={@mode == :show}
        author_membership={@author_membership}
        can_edit?={can_edit_event?(@publication.event, @current_scope)}
        can_relay?={@can_relay?}
        current_member_participation={@current_member_participation}
        participations={@participations}
        publication={@publication}
        relayer_membership={@relayer_membership}
        show_origin_space?={@show_origin_space?}
        target={@myself}
        user_tz={@user_tz}
      />

      <Event.event_form
        :if={@mode == :edit}
        form={@event_form}
        show_end_date?={@show_end_date?}
        target={@myself}
        user_tz={@user_tz}
      />

      <Event.converted_layer_form
        :if={@mode == :converted_layer}
        form={@converted_layer_form}
        target={@myself}
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
      if converted_event?(socket.assigns.publication.event) do
        socket
        |> assign(:mode, :converted_layer)
        |> assign(:converted_layer_form, converted_layer_form(socket.assigns.publication.event))
      else
        socket
        |> assign(:mode, :edit)
        |> then(fn socket ->
          event_form =
            Event.FormState.edit(socket.assigns.publication.event, socket.assigns.current_scope)

          socket
          |> assign(:event_form, event_form)
          |> assign(:show_end_date?, Event.FormState.show_end_date?(event_form))
        end)
      end

    {:noreply, socket}
  end

  def handle_event("event_form_validate", %{"form" => params}, socket) do
    params =
      Event.FormState.normalize_hidden_end_date_params(
        socket.assigns.event_form,
        params,
        socket.assigns.show_end_date?
      )

    event_form = Event.FormState.validate(socket.assigns.event_form, params)

    socket =
      socket
      |> assign(:event_form, event_form)
      |> assign(
        :show_end_date?,
        socket.assigns.show_end_date? || Event.FormState.show_end_date?(event_form)
      )

    {:noreply, socket}
  end

  def handle_event("event_form_end_date_add", _params, socket) do
    {:noreply, assign(socket, :show_end_date?, true)}
  end

  def handle_event("event_form_end_date_remove", _params, socket) do
    event_form = Event.FormState.collapse_end_date(socket.assigns.event_form)

    {:noreply,
     socket
     |> assign(:event_form, event_form)
     |> assign(:show_end_date?, false)}
  end

  def handle_event("event_form_submit", %{"form" => params}, socket) do
    params =
      Event.FormState.normalize_hidden_end_date_params(
        socket.assigns.event_form,
        params,
        socket.assigns.show_end_date?
      )

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
      |> assign(:show_end_date?, false)
      |> assign(:mode, :show)

    {:noreply, socket}
  end

  def handle_event("converted_layer_submit", %{"converted_layer" => params}, socket) do
    socket =
      case Events.update_converted_event_layer(socket.assigns.publication.event, params,
             scope: socket.assigns.current_scope
           ) do
        {:ok, _event} ->
          send(self(), {:event_details, :saved})
          socket

        {:error, _error} ->
          assign(socket, :converted_layer_form, to_form(params, as: :converted_layer))
      end

    {:noreply, socket}
  end

  def handle_event("converted_layer_cancel", _params, socket) do
    {:noreply, assign(socket, :mode, :show)}
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
    |> assign(:author_membership, nil)
    |> assign(:event_form, nil)
    |> assign(:converted_layer_form, nil)
    |> assign(:show_end_date?, false)
    |> assign(:mode, :show)
    |> assign(:relayer_membership, nil)
    |> assign(:show_origin_space?, false)
    |> assign(:current_member_participation, nil)
    |> assign(:participations, [])
    |> assign(:relay_error, nil)
    |> assign(:relay_form, nil)
    |> assign(:relay_target_spaces, [])
  end

  defp maybe_reset_state(socket, false), do: socket

  defp maybe_load_relay_eligibility(socket, true) do
    load_relay_eligibility(socket)
  end

  defp maybe_load_relay_eligibility(socket, false), do: socket

  defp converted_event?(%{source_external_event_id: source_external_event_id}),
    do: not is_nil(source_external_event_id)

  defp can_edit_event?(event, scope) do
    action = if converted_event?(event), do: :update_converted_layer, else: :update

    Ash.can?({event, action}, scope)
  end

  defp converted_layer_form(event) do
    %{
      "description" => event.description,
      "title" => event.title
    }
    |> to_form(as: :converted_layer)
  end

  defp maybe_load_author_membership(socket, true) do
    case Accounts.get_membership(
           socket.assigns.publication.space,
           socket.assigns.publication.event.author
         ) do
      {:ok, membership} -> assign(socket, :author_membership, membership)
      {:error, _error} -> assign(socket, :author_membership, nil)
    end
  end

  defp maybe_load_author_membership(socket, false), do: socket

  defp maybe_load_participations(socket, true) do
    publication = socket.assigns.publication
    scope = socket.assigns.current_scope

    participations =
      [publication.id]
      |> Events.event_participations_query()
      |> Ash.read!(scope: scope)

    current_membership =
      case Accounts.get_membership(scope.tenant.id, scope.actor.id) do
        {:ok, membership} -> membership
        {:error, _error} -> nil
      end

    assign(socket,
      current_member_participation:
        current_member_participation(participations, current_membership),
      participations: participations
    )
  end

  defp maybe_load_participations(socket, false), do: socket

  defp current_member_participation(_participations, nil), do: nil

  defp current_member_participation(participations, current_membership) do
    Enum.find(participations, &(&1.membership_id == current_membership.id))
  end

  defp maybe_load_relayer_membership(socket, true) do
    case socket.assigns.publication do
      %{publication_type: :relay, published_by: published_by, space: space} ->
        case Accounts.get_membership(space, published_by) do
          {:ok, membership} -> assign(socket, :relayer_membership, membership)
          {:error, _error} -> assign(socket, :relayer_membership, nil)
        end

      _publication ->
        assign(socket, :relayer_membership, nil)
    end
  end

  defp maybe_load_relayer_membership(socket, false), do: socket

  defp maybe_load_origin_space_visibility(socket, true) do
    case socket.assigns.publication do
      %{publication_type: :relay, event: %{space: origin_space}} ->
        case Accounts.get_membership(origin_space, socket.assigns.current_scope.actor) do
          {:ok, membership} -> assign(socket, :show_origin_space?, not is_nil(membership))
          {:error, _error} -> assign(socket, :show_origin_space?, false)
        end

      _publication ->
        assign(socket, :show_origin_space?, false)
    end
  end

  defp maybe_load_origin_space_visibility(socket, false), do: socket

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
