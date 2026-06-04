defmodule WikWeb.EventsLive.EventForm do
  use WikWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_patch: 2]

  alias AshPhoenix.Form
  alias Wik.Events
  alias WikWeb.Components.Event.FormState
  alias WikWeb.EventsLive
  alias WikWeb.EventsLive.Interest
  alias WikWeb.EventsLive.Params

  def open(socket) do
    current_scope = socket.assigns.current_scope
    active_tz = socket.assigns.active_tz
    form = FormState.new(current_scope, active_tz)

    assign(socket, :modal, {:event_form, form, FormState.show_end_date?(form), Interest.form()})
  end

  def validate(socket, %{"form" => params} = all_params) do
    show_end_date? = show_end_date?(socket)
    interest_form = Interest.form_from_params(Map.get(all_params, "interest", %{}), nil)

    params =
      FormState.normalize_hidden_end_date_params(
        form(socket),
        params,
        show_end_date?
      )

    form =
      socket
      |> form()
      |> FormState.validate(params)

    assign(
      socket,
      :modal,
      {:event_form, form, show_end_date? || FormState.show_end_date?(form), interest_form}
    )
  end

  def show_end_date(socket), do: put_show_end_date(socket, true)

  def hide_end_date(socket) do
    form =
      socket
      |> form()
      |> FormState.collapse_end_date()

    case socket.assigns.modal do
      {:event_form, _current_form, _show_end_date?, interest_form} ->
        assign(socket, :modal, {:event_form, form, false, interest_form})

      _modal ->
        socket
    end
  end

  def submit(socket, %{"form" => params} = all_params) do
    current_scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline
    show_end_date? = show_end_date?(socket)
    interest_params = Map.get(all_params, "interest", %{})

    params =
      FormState.normalize_hidden_end_date_params(
        form(socket),
        params,
        show_end_date?
      )

    case Form.submit(form(socket),
           params: params,
           action_opts: [scope: current_scope]
         ) do
      {:ok, event} ->
        _ = Events.record_event_interest(event, interest_params, scope: current_scope)

        page_params = Params.page_params(timeline.show_external?, timeline.future_windows)

        socket
        |> assign(:modal, nil)
        |> EventsLive.refresh_page_data()
        |> push_patch(to: ~p"/#{current_scope.tenant.slug}/events?#{page_params}")

      {:error, form} ->
        assign(
          socket,
          :modal,
          {:event_form, form, show_end_date? || FormState.show_end_date?(form),
           Interest.form_from_params(interest_params, nil)}
        )
    end
  end

  def cancel(socket) do
    case socket.assigns.modal do
      {:event_form, _form, _show_end_date?, _interest_form} -> assign(socket, :modal, nil)
      _modal -> socket
    end
  end

  defp form(%{assigns: %{modal: modal}}), do: form(modal)
  defp form({:event_form, form, _show_end_date?, _interest_form}), do: form
  defp form(_modal), do: nil

  defp show_end_date?(%{assigns: %{modal: modal}}), do: show_end_date?(modal)
  defp show_end_date?({:event_form, _form, show_end_date?, _interest_form}), do: show_end_date?
  defp show_end_date?(_modal), do: false

  defp put_show_end_date(socket, show_end_date?) do
    case socket.assigns.modal do
      {:event_form, form, _current_show_end_date?, interest_form} ->
        assign(socket, :modal, {:event_form, form, show_end_date?, interest_form})

      _modal ->
        socket
    end
  end
end
