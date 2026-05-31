defmodule Wik.Events.ExternalCalendar do
  @moduledoc """
  Fetches, parses, expands, and materializes external ICS calendar feeds.

  This facade keeps the public feature API stable while delegating the
  implementation to focused fetch, sync, and presentation modules.
  """

  alias Wik.Events.ExternalCalendar.Presentation
  alias Wik.Events.ExternalCalendar.Sync

  defdelegate load_subscriptions(subscriptions, opts \\ []), to: Presentation
  defdelegate display_name(subscription, calendar_name \\ nil), to: Presentation
  defdelegate materialization_horizon_end(now \\ DateTime.utc_now()), to: Sync
  defdelegate recent_past_start(now \\ DateTime.utc_now()), to: Sync
  defdelegate sync_subscription(subscription, opts \\ []), to: Sync
  defdelegate sync_subscription_by_id(subscription_id, opts \\ []), to: Sync
  defdelegate sync_all_subscriptions(opts \\ []), to: Sync
end
