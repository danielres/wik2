defmodule WikWeb.EventsLive.Interest do
  import Phoenix.Component, only: [assign: 3, to_form: 2]
  import Phoenix.LiveView, only: [put_flash: 3]

  alias Wik.Events
  alias WikWeb.EventsLive

  def open_internal(socket, id) do
    publication = Enum.find(socket.assigns.timeline.internal_publications, &(&1.id == id))
    item = Enum.find(socket.assigns.timeline.internal_items, &(&1.publication.id == id))

    assign(
      socket,
      :modal,
      {:event_interest, :internal, publication, form(item && item.current_member_participation)}
    )
  end

  def open_external(socket, id) do
    external_event =
      socket.assigns.timeline.external_items
      |> Enum.map(& &1.event)
      |> Enum.find(&(&1.id == id))

    assign(socket, :modal, {:event_interest, :external, external_event, form()})
  end

  def cancel(socket), do: assign(socket, :modal, nil)

  def submit(socket, %{"interest" => params}) do
    scope = socket.assigns.current_scope

    case socket.assigns.modal do
      {:event_interest, :internal, publication, _form} ->
        case Events.record_interest(publication, params, scope: scope) do
          {:ok, _participation} -> after_saved(socket)
          {:error, error} -> assign_error(socket, params, error)
        end

      {:event_interest, :external, external_event, _form} ->
        case Events.record_external_interest(external_event, params, scope: scope) do
          {:ok, _result} -> after_saved(socket)
          {:error, error} -> assign_error(socket, params, error)
        end

      _modal ->
        socket
    end
  end

  def form(participation \\ nil, error \\ nil) do
    %{
      "extra_info" => participation && participation.extra_info,
      "interest" => (participation && participation.interest) || 5
    }
    |> form_from_params(error)
  end

  def form_from_params(params, error) do
    form = to_form(params, as: :interest)

    if error do
      Map.put(form, :errors, interest: {error_message(error), []})
    else
      form
    end
  end

  defp after_saved(socket) do
    socket
    |> assign(:modal, nil)
    |> EventsLive.refresh_page_data()
  end

  defp assign_error(socket, params, error) do
    case socket.assigns.modal do
      {:event_interest, source_type, source, _form} ->
        assign(
          socket,
          :modal,
          {:event_interest, source_type, source, form_from_params(params, error)}
        )

      _modal ->
        put_flash(socket, :error, error_message(error))
    end
  end

  defp error_message(:invalid_interest), do: "Interest must be between 0 and 10"
  defp error_message(:membership_not_found), do: "Could not find your membership"
  defp error_message(error) when is_binary(error), do: error
  defp error_message(error), do: Exception.message(error)
end
