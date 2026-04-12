defmodule QblogWeb.Presence do
  @moduledoc """
  Tracks online users in group-scoped LiveViews.
  """

  use Phoenix.Presence,
    otp_app: :qblog,
    pubsub_server: Qblog.PubSub

  require Ash.Query

  alias Qblog.Accounts.User

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def fetch(_topic, presences) do
    user_ids = Map.keys(presences)

    users =
      User
      |> Ash.Query.filter(id in ^user_ids)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.id, &1})

    for {user_id, %{metas: [meta | metas]}} <- presences, into: %{} do
      {user_id, %{id: user_id, metas: [meta | metas], user: Map.get(users, user_id)}}
    end
  end

  @impl true
  def handle_metas(topic, %{joins: joins, leaves: leaves}, presences, state) do
    Enum.each(joins, fn {user_id, presence} ->
      broadcast_proxy_event(topic, :join, %{
        id: user_id,
        metas: Map.fetch!(presences, user_id),
        user: presence.user
      })
    end)

    Enum.each(leaves, fn {user_id, presence} ->
      metas =
        case Map.fetch(presences, user_id) do
          {:ok, presence_metas} -> presence_metas
          :error -> []
        end

      broadcast_proxy_event(topic, :leave, %{id: user_id, metas: metas, user: presence.user})
    end)

    {:ok, state}
  end

  @spec list_online_users_in_group(String.t()) :: [map()]
  def list_online_users_in_group(group_id) do
    group_id
    |> build_group_topic()
    |> list()
    |> Enum.map(fn {_id, presence} -> presence end)
    |> Enum.sort_by(&presence_sort_key/1)
  end

  @spec subscribe_to_group(String.t()) :: :ok | {:error, term()}
  def subscribe_to_group(group_id) do
    group_id
    |> build_group_topic()
    |> build_proxy_topic()
    |> then(&Phoenix.PubSub.subscribe(Qblog.PubSub, &1))
  end

  @spec track_in_liveview(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def track_in_liveview(socket, url) do
    if Phoenix.LiveView.connected?(socket) do
      case socket.assigns[:current_scope] do
        %{actor: user, tenant: group} when not is_nil(user) and not is_nil(group) ->
          path = url |> URI.parse() |> Map.get(:path, "/")
          _ = track_user_presence(user, path, group.id)
          socket

        _ ->
          socket
      end
    else
      socket
    end
  end

  @spec track_user_presence(Qblog.Accounts.User.t(), String.t(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def track_user_presence(user, path, group_id) do
    meta = %{group_id: group_id, path: path}
    topic = build_group_topic(group_id)

    case track(self(), topic, user.id, meta) do
      {:ok, _meta} = ok ->
        ok

      {:error, {:already_tracked, _pid, _user_id, _meta}} ->
        case update(self(), topic, user.id, meta) do
          {:ok, updated_meta} = ok ->
            broadcast_proxy_event(topic, :update, %{id: user.id, meta: updated_meta})
            ok

          error ->
            error
        end

      error ->
        error
    end
  end

  def users_at_path(presences, path) do
    for presence <- presences,
        meta <- presence.metas,
        meta.path == path,
        do: presence.user |> to_string()
  end

  defp broadcast_proxy_event(topic, event, payload) do
    Phoenix.PubSub.local_broadcast(Qblog.PubSub, build_proxy_topic(topic), {__MODULE__, {event, payload}})
  end

  defp build_group_topic(group_id), do: "group:#{group_id}:users"

  defp build_proxy_topic(topic), do: "proxy:#{topic}"

  defp presence_sort_key(%{user: user}) when not is_nil(user), do: to_string(user)
  defp presence_sort_key(%{id: id}), do: id
end
