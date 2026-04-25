defmodule QblogWeb.Presence do
  @moduledoc """
  Tracks online users in group-scoped LiveViews.
  """

  use Phoenix.Presence,
    otp_app: :qblog,
    pubsub_server: Qblog.PubSub

  require Ash.Query

  alias Qblog.Access
  alias Qblog.Accounts.User

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def fetch(topic, presences) do
    user_ids = Map.keys(presences)
    group_id = group_id_from_topic(topic)

    users =
      User
      |> Ash.Query.filter(id in ^user_ids)
      |> Ash.read!(authorize?: false)
      |> Map.new(&{&1.id, &1})

    avatar_urls = list_avatar_urls(group_id, user_ids)

    for {user_id, %{metas: [meta | metas]}} <- presences, into: %{} do
      {user_id,
       %{
         avatar_url: Map.get(avatar_urls, user_id),
         id: user_id,
         metas: [meta | metas],
         user: Map.get(users, user_id)
       }}
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

          _ =
            track_user_presence(user, path, group.id,
              editing_block_id: socket.assigns[:editing_block_id],
              tab_id: socket.assigns[:tab_id]
            )

          Phoenix.Component.assign(socket, :presence_path, path)

        _ ->
          socket
      end
    else
      socket
    end
  end

  @spec track_user_presence(Qblog.Accounts.User.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def track_user_presence(user, path, group_id, opts \\ []) do
    meta = build_presence_meta(path, group_id, opts)
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

  @spec presences_to_locks([map()], String.t()) :: %{optional(String.t()) => map()}
  def presences_to_locks(presences, current_user_id) do
    presences_to_locks(presences, current_user_id, nil)
  end

  @spec presences_to_locks([map()], String.t(), String.t() | nil) ::
          %{optional(String.t()) => map()}
  def presences_to_locks(presences, current_user_id, current_tab_id) do
    presences
    |> Enum.flat_map(fn presence ->
      presence
      |> Map.get(:metas, [])
      |> Enum.map(&{presence, &1})
    end)
    |> Enum.reduce(%{}, fn {presence, meta}, locks ->
      case meta[:editing_block_id] do
        nil ->
          locks

        block_id ->
          if presence.id == current_user_id and
               meta[:tab_id] == current_tab_id do
            locks
          else
            Map.put_new(locks, block_id, %{
              block_id: block_id,
              user: presence.user,
              user_id: presence.id
            })
          end
      end
    end)
  end

  defp broadcast_proxy_event(topic, event, payload) do
    Phoenix.PubSub.local_broadcast(
      Qblog.PubSub,
      build_proxy_topic(topic),
      {__MODULE__, {event, payload}}
    )
  end

  defp list_avatar_urls(nil, _user_ids), do: %{}

  defp list_avatar_urls(_group_id, []), do: %{}

  defp list_avatar_urls(group_id, user_ids) do
    with {:ok, grants} <- Access.list_group_grants_for_users(group_id, user_ids) do
      grants
      |> Enum.reject(&is_nil(&1.external_identity.avatar_url))
      |> Map.new(&{&1.user_id, &1.external_identity.avatar_url})
    else
      {:error, _error} -> %{}
    end
  end

  defp build_presence_meta(path, group_id, opts) do
    %{
      editing_block_id: Keyword.get(opts, :editing_block_id),
      group_id: group_id,
      tab_id: Keyword.get(opts, :tab_id),
      path: path
    }
  end

  defp build_group_topic(group_id), do: "group:#{group_id}:users"

  defp build_proxy_topic(topic), do: "proxy:#{topic}"

  defp group_id_from_topic("group:" <> rest) do
    rest |> String.replace_suffix(":users", "")
  end

  defp group_id_from_topic(_topic), do: nil

  defp presence_sort_key(%{user: user}) when not is_nil(user), do: to_string(user)
  defp presence_sort_key(%{id: id}), do: id
end
