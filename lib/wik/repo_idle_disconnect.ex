defmodule Wik.RepoIdleDisconnect do
  @moduledoc """
  Disconnects idle Repo connections so serverless Postgres can suspend.

  This keeps the Phoenix app process warm while allowing the database pool to
  close its PgBouncer/Postgres connections after the app has stopped querying.
  """

  use GenServer

  require Logger

  @telemetry_event [:wik, :repo, :query]
  @telemetry_handler_id "#{__MODULE__}-repo-query"

  # Neon Free suspends after 5 minutes of database inactivity. Waiting a bit
  # longer avoids disconnecting between ordinary page-load query bursts.
  @default_idle_after_ms :timer.minutes(10)

  # A one-minute check is frequent enough for scale-to-zero without adding
  # meaningful scheduler work to an idle Fly machine.
  @default_check_interval_ms :timer.minutes(1)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    state = %{
      repo: Keyword.get(opts, :repo, Wik.Repo),
      idle_after_ms: Keyword.get(opts, :idle_after_ms, @default_idle_after_ms),
      check_interval_ms: Keyword.get(opts, :check_interval_ms, @default_check_interval_ms),
      last_query_at: monotonic_ms(),
      disconnected?: false
    }

    :ok =
      :telemetry.attach(
        @telemetry_handler_id,
        @telemetry_event,
        &__MODULE__.handle_repo_query/4,
        %{server: self()}
      )

    schedule_check(state.check_interval_ms)

    {:ok, state}
  end

  @impl true
  def handle_info(:check_idle, state) do
    state =
      if disconnect_due?(state) do
        Logger.debug("Disconnecting idle Repo connections")
        state.repo.disconnect_all(0)
        %{state | disconnected?: true}
      else
        state
      end

    schedule_check(state.check_interval_ms)

    {:noreply, state}
  end

  def handle_info(:repo_query, state) do
    {:noreply, %{state | last_query_at: monotonic_ms(), disconnected?: false}}
  end

  @impl true
  def terminate(_reason, _state) do
    :telemetry.detach(@telemetry_handler_id)
    :ok
  end

  def handle_repo_query(_event, _measurements, _metadata, %{server: server}) do
    send(server, :repo_query)
  end

  defp disconnect_due?(state) do
    not state.disconnected? and monotonic_ms() - state.last_query_at >= state.idle_after_ms
  end

  defp schedule_check(interval_ms) do
    Process.send_after(self(), :check_idle, interval_ms)
  end

  defp monotonic_ms do
    System.monotonic_time(:millisecond)
  end
end
