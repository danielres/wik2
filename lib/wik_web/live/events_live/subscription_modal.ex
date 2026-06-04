defmodule WikWeb.EventsLive.SubscriptionModal do
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]

  alias Utils.Log
  alias Utils.Values
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias WikWeb.EventsLive
  alias WikWeb.EventsLive.SubscriptionState

  def new(socket) do
    assign(socket, :modal, {:new_subscription, SubscriptionState.create_form(), nil})
  end

  def show(socket, id), do: select_subscription_modal(socket, id)

  def submit(socket, %{"subscription" => %{"ics_url" => ics_url}}) do
    scope = socket.assigns.current_scope
    ics_url = String.trim(ics_url)

    case ExternalCalendarSubscription.create(%{ics_url: ics_url}, scope: scope) do
      {:ok, subscription} ->
        case ExternalCalendar.sync_subscription(subscription) do
          {:ok, _subscription} ->
            socket
            |> assign(:modal, nil)
            |> EventsLive.refresh_page_data()

          {:error, error} ->
            _ = ExternalCalendarSubscription.destroy(subscription, scope: scope)

            assign(
              socket,
              :modal,
              {:new_subscription, SubscriptionState.create_form(ics_url), error_message(error)}
            )
        end

      {:error, %Ash.Error.Invalid{} = error} ->
        assign(
          socket,
          :modal,
          {:new_subscription, SubscriptionState.create_form(ics_url),
           Ash.Error.to_error_class(error).message}
        )

      {:error, error} ->
        assign(
          socket,
          :modal,
          {:new_subscription, SubscriptionState.create_form(ics_url), error_message(error)}
        )
    end
  end

  def remove(socket, id) do
    scope = socket.assigns.current_scope

    case SubscriptionState.find(socket.assigns.subscriptions, id) do
      nil ->
        socket

      subscription ->
        case ExternalCalendarSubscription.destroy(subscription, scope: scope) do
          :ok ->
            socket
            |> assign(:modal, nil)
            |> EventsLive.refresh_page_data()

          {:ok, _subscription} ->
            socket
            |> assign(:modal, nil)
            |> EventsLive.refresh_page_data()

          {:error, error} ->
            put_flash(socket, :error, error_message(error))
        end
    end
  end

  def refresh(socket, id) do
    scope = socket.assigns.current_scope

    case SubscriptionState.find(socket.assigns.subscriptions, id) do
      nil ->
        socket

      subscription ->
        case ExternalCalendar.sync_subscription(subscription) do
          {:ok, _subscription} ->
            socket
            |> EventsLive.refresh_page_data()
            |> select_subscription_modal(id)

          {:error, error} ->
            Log.scoped_error(scope, error, "external_calendar_subscription_refresh failed")
            put_flash(socket, :error, error_message(error))
        end
    end
  end

  def submit_name(socket, %{
        "subscription_name" => %{"id" => subscription_id, "custom_name" => custom_name}
      }) do
    scope = socket.assigns.current_scope

    with {:ok, subscription} <-
           Ash.get(ExternalCalendarSubscription, subscription_id, scope: scope),
         {:ok, _updated_subscription} <-
           ExternalCalendarSubscription.update_custom_name(
             subscription,
             %{custom_name: Values.blank_to_nil(custom_name)},
             scope: scope
           ) do
      socket
      |> EventsLive.refresh_page_data()
      |> assign(:modal, nil)
    else
      {:error, error} ->
        Log.scoped_error(scope, error, "external_calendar_subscription_name_submit failed")
        put_flash(socket, :error, error_message(error))
    end
  end

  defp select_subscription_modal(socket, subscription_id) do
    subscription = SubscriptionState.find(socket.assigns.subscriptions, subscription_id)

    assign(
      socket,
      :modal,
      {:subscription, subscription, SubscriptionState.name_form(subscription)}
    )
  end

  defp error_message(%Ash.Error.Forbidden{}), do: "You are not allowed to manage subscriptions"

  defp error_message(%Ash.Error.Invalid{} = error) do
    case Ash.Error.to_error_class(error) do
      %{message: message} when is_binary(message) -> message
      _ -> Exception.message(error)
    end
  end

  defp error_message(error) when is_binary(error), do: error
  defp error_message(error), do: Exception.message(error)
end
