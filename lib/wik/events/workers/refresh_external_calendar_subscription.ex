defmodule Wik.Events.Workers.RefreshExternalCalendarSubscription do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Wik.Events.ExternalCalendar

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"subscription_id" => subscription_id}}) do
    case ExternalCalendar.sync_subscription_by_id(subscription_id) do
      {:ok, _subscription} -> :ok
      {:error, :not_found} -> :ok
      {:error, error} -> {:error, error}
    end
  end
end
