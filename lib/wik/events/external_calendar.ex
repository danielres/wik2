defmodule Wik.Events.ExternalCalendar do
  @moduledoc """
  Fetches, parses, expands, and materializes external ICS calendar feeds.

  This facade keeps the public feature API stable while delegating the
  implementation to focused fetch, sync, and presentation modules.
  """

  alias Wik.Events.ExternalCalendar.Fetch
  alias Wik.Events.ExternalCalendar.Presentation
  alias Wik.Events.ExternalCalendar.Sync

  def fetch_subscription_cache(subscription, http_get \\ Fetch.http_get()) do
    Fetch.fetch_subscription_cache(subscription, http_get)
  end

  def fetch_subscription_events(subscription, http_get \\ Fetch.http_get()) do
    with {:ok, calendar_data} <- Fetch.fetch_remote_calendar(subscription, http_get) do
      {:ok,
       Sync.materialized_events(
         subscription,
         calendar_data.calendar,
         calendar_data.cached_calendar_name,
         calendar_data.raw_event_metadata
       )}
    end
  end

  defdelegate load_subscriptions(subscriptions, opts \\ []), to: Presentation
  defdelegate display_name(subscription, calendar_name \\ nil), to: Presentation
  defdelegate materialization_horizon_end(now \\ DateTime.utc_now()), to: Sync
  defdelegate recent_past_start(now \\ DateTime.utc_now()), to: Sync
  defdelegate sync_subscription(subscription, opts \\ []), to: Sync
  defdelegate sync_subscription_by_id(subscription_id, opts \\ []), to: Sync
  defdelegate sync_all_subscriptions(opts \\ []), to: Sync
end
