defmodule Wik.Events.ExternalCalendar.StaleRefresh do
  @moduledoc false

  use GenServer

  require Ash.Query
  require Logger

  alias Wik.Events.ExternalCalendar.Sync
  alias Wik.Events.ExternalCalendarSubscription

  @default_stale_after :timer.hours(1)

  def enabled? do
    :wik
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:enabled?, true)
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def trigger(scope, opts \\ [])

  def trigger(%Wik.Scope{tenant: %{id: space_id}} = scope, opts) when is_binary(space_id) do
    GenServer.cast(__MODULE__, {:trigger, scope, opts})
  end

  def trigger(_scope, _opts), do: :ok

  def refresh_space(%Wik.Scope{} = scope, opts \\ []) do
    now = Keyword.get_lazy(opts, :now, &DateTime.utc_now/0)
    stale_after = Keyword.get(opts, :stale_after, @default_stale_after)

    scope
    |> stale_subscriptions(now, stale_after)
    |> Task.async_stream(&sync_subscription_safely(&1, opts),
      max_concurrency: 1,
      timeout: :infinity
    )
    |> Stream.run()

    :ok
  end

  @impl true
  def init(opts) do
    {:ok,
     %{
       task_supervisor: Keyword.fetch!(opts, :task_supervisor),
       running_by_space_id: %{},
       refs_by_ref: %{}
     }}
  end

  @impl true
  def handle_cast({:trigger, %Wik.Scope{tenant: %{id: space_id}} = scope, opts}, state) do
    if Map.has_key?(state.running_by_space_id, space_id) do
      {:noreply, state}
    else
      task =
        Task.Supervisor.async_nolink(state.task_supervisor, fn ->
          refresh_space(scope, opts)
        end)

      state =
        state
        |> put_in([:running_by_space_id, space_id], task.ref)
        |> put_in([:refs_by_ref, task.ref], space_id)

      {:noreply, state}
    end
  end

  def handle_cast(_message, state), do: {:noreply, state}

  @impl true
  def handle_info({ref, _result}, state) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    {:noreply, clear_ref(state, ref)}
  end

  def handle_info({:DOWN, ref, :process, _pid, _reason}, state) do
    {:noreply, clear_ref(state, ref)}
  end

  defp stale_subscriptions(scope, now, stale_after) do
    threshold = DateTime.add(now, -stale_after, :millisecond)

    ExternalCalendarSubscription
    |> Ash.Query.filter(is_nil(cached_at) or cached_at < ^threshold)
    |> Ash.read!(scope: scope)
  end

  defp sync_subscription_safely(subscription, opts) do
    case Sync.sync_subscription(subscription, opts) do
      {:ok, _subscription} ->
        :ok

      {:error, error} ->
        Logger.warning("External calendar stale refresh failed: #{inspect(error)}")
        :ok
    end
  rescue
    error ->
      Logger.warning("External calendar stale refresh crashed: #{Exception.message(error)}")
      :ok
  end

  defp clear_ref(state, ref) do
    {space_id, refs_by_ref} = Map.pop(state.refs_by_ref, ref)

    running_by_space_id =
      case space_id do
        nil -> state.running_by_space_id
        space_id -> Map.delete(state.running_by_space_id, space_id)
      end

    %{state | refs_by_ref: refs_by_ref, running_by_space_id: running_by_space_id}
  end
end
