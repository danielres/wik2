defmodule WikWeb.EventsLive.Components.InterestForm do
  use WikWeb, :live_component

  alias Wik.Events
  alias WikWeb.Components.Event

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> maybe_reset_form()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="event-interest-form"
        data-testid="event-interest-form"
        phx-submit="event_interest_submit"
        phx-target={@myself}
      >
        <div class="space-y-4">
          <Event.interest_fields form={@form} />

          <div class="flex justify-end">
            <button
              type="submit"
              class="btn btn-accent btn-soft btn-sm"
              data-testid="event-interest-submit"
            >
              Save
            </button>
          </div>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("event_interest_submit", %{"interest" => params}, socket) do
    case socket.assigns.source_type do
      :internal ->
        case Events.record_interest(socket.assigns.publication, params,
               scope: socket.assigns.current_scope
             ) do
          {:ok, participation} -> saved(socket, participation)
          {:error, error} -> {:noreply, assign(socket, :form, form_from_params(params, error))}
        end

      :external ->
        case Events.record_external_interest(socket.assigns.external_event, params,
               scope: socket.assigns.current_scope
             ) do
          {:ok, result} -> saved(socket, result)
          {:error, error} -> {:noreply, assign(socket, :form, form_from_params(params, error))}
        end
    end
  end

  defp saved(socket, result) do
    send(self(), {:events_live, {:interest_saved, result}})
    {:noreply, socket}
  end

  defp maybe_reset_form(socket) do
    source_key = {socket.assigns.source_type, socket.assigns.source_id}

    if socket.assigns[:source_key] == source_key and not is_nil(socket.assigns[:form]) do
      socket
    else
      socket
      |> assign(:source_key, source_key)
      |> assign(:form, interest_form(socket.assigns.current_member_participation))
    end
  end

  defp interest_form(participation) do
    %{
      "extra_info" => participation && participation.extra_info,
      "interest" => (participation && participation.interest) || 5
    }
    |> form_from_params(nil)
  end

  defp form_from_params(params, error) do
    form = to_form(params, as: :interest)

    if error do
      Map.put(form, :errors, interest: {error_message(error), []})
    else
      form
    end
  end

  defp error_message(:invalid_interest), do: "Interest must be between 0 and 10"
  defp error_message(:membership_not_found), do: "Could not find your membership"
  defp error_message(error) when is_binary(error), do: error
  defp error_message(error), do: Exception.message(error)
end
