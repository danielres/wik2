defmodule WikWeb.EventsLive.Components.EventForm do
  use WikWeb, :live_component

  alias AshPhoenix.Form
  alias Wik.Events
  alias WikWeb.Components.Event

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:form, fn ->
        Event.FormState.new(assigns.current_scope, assigns.user_tz)
      end)
      |> assign_new(:interest_form, fn -> interest_form() end)
      |> assign_show_end_date()

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <Event.event_form
        form={@form}
        interest_form={@interest_form}
        show_end_date?={@show_end_date?}
        target={@myself}
        user_tz={@user_tz}
      />
    </div>
    """
  end

  @impl true
  def handle_event("event_form_validate", %{"form" => params} = all_params, socket) do
    params =
      Event.FormState.normalize_hidden_end_date_params(
        socket.assigns.form,
        params,
        socket.assigns.show_end_date?
      )

    form = Event.FormState.validate(socket.assigns.form, params)

    socket =
      socket
      |> assign(:form, form)
      |> assign(:interest_form, interest_form_from_params(Map.get(all_params, "interest", %{})))
      |> assign(
        :show_end_date?,
        socket.assigns.show_end_date? || Event.FormState.show_end_date?(form)
      )

    {:noreply, socket}
  end

  def handle_event("event_form_end_date_add", _params, socket) do
    {:noreply, assign(socket, :show_end_date?, true)}
  end

  def handle_event("event_form_end_date_remove", _params, socket) do
    form = Event.FormState.collapse_end_date(socket.assigns.form)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:show_end_date?, false)}
  end

  def handle_event("event_form_submit", %{"form" => params} = all_params, socket) do
    interest_params = Map.get(all_params, "interest", %{})

    params =
      Event.FormState.normalize_hidden_end_date_params(
        socket.assigns.form,
        params,
        socket.assigns.show_end_date?
      )

    socket =
      case Form.submit(socket.assigns.form,
             params: params,
             action_opts: [scope: socket.assigns.current_scope]
           ) do
        {:ok, event} ->
          _ =
            Events.record_event_interest(event, interest_params,
              scope: socket.assigns.current_scope
            )

          send(self(), {:events_live, {:event_created, event}})
          socket

        {:error, form} ->
          socket
          |> assign(:form, form)
          |> assign(:interest_form, interest_form_from_params(interest_params))
      end

    {:noreply, socket}
  end

  def handle_event("event_form_cancel", _params, socket) do
    send(self(), {:events_live, :close})
    {:noreply, socket}
  end

  defp interest_form(participation \\ nil) do
    %{
      "extra_info" => participation && participation.extra_info,
      "interest" => (participation && participation.interest) || 5
    }
    |> interest_form_from_params()
  end

  defp interest_form_from_params(params, error \\ nil) do
    form = to_form(params, as: :interest)

    if error do
      Map.put(form, :errors, interest: {error_message(error), []})
    else
      form
    end
  end

  defp error_message(:invalid_interest), do: "Interest must be between 0 and 10"
  defp error_message(error) when is_binary(error), do: error
  defp error_message(error), do: Exception.message(error)

  defp assign_show_end_date(socket) do
    assign_new(socket, :show_end_date?, fn ->
      Event.FormState.show_end_date?(socket.assigns.form)
    end)
  end
end
