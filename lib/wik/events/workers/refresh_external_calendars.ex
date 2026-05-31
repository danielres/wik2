defmodule Wik.Events.Workers.RefreshExternalCalendars do
  use Oban.Worker, queue: :default, max_attempts: 1

  alias Wik.Events.ExternalCalendar

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    ExternalCalendar.sync_all_subscriptions()
  end
end
