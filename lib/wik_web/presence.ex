defmodule WikWeb.Presence do
  @moduledoc """
  Tracks online users in space-scoped LiveViews.
  """

  use Phoenix.Presence,
    otp_app: :wik,
    pubsub_server: Wik.PubSub

  require Ash.Query

  alias Wik.Accounts
  alias Wik.Accounts.User

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def fetch(topic, presences) do
    user_ids = Map.keys(presences)
    space_id = space_id_from_topic(topic)

    memberships = fetch_memberships_by_user_id(space_id, user_ids)

    presentation_by_user_id = present_memberships(memberships)
    users = safe_list_users_by_id(user_ids, presentation_by_user_id)

    for {user_id, %{metas: [meta | metas]}} <- presences, into: %{} do
      membership =
        presentation_by_user_id
        |> Map.get(user_id, %{})
        |> normalize_membership(Map.get(users, user_id), user_id)

      {user_id,
       %{
         display_name: Map.get(membership, :display_name) || user_id,
         id: user_id,
         membership: membership,
         metas: [meta | metas],
         user: Map.get(membership, :user) || Map.get(users, user_id)
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

  @spec list_online_users_in_space(String.t()) :: [map()]
  def list_online_users_in_space(space_id) do
    space_id
    |> build_space_topic()
    |> list()
    |> Enum.map(fn {_id, presence} -> presence end)
    |> Enum.sort_by(&presence_sort_key/1)
  end

  @spec subscribe_to_space(String.t()) :: :ok | {:error, term()}
  def subscribe_to_space(space_id) do
    space_id
    |> build_space_topic()
    |> build_proxy_topic()
    |> then(&Phoenix.PubSub.subscribe(Wik.PubSub, &1))
  end

  @spec track_in_liveview(Phoenix.LiveView.Socket.t(), String.t()) :: Phoenix.LiveView.Socket.t()
  def track_in_liveview(socket, url) do
    if Phoenix.LiveView.connected?(socket) do
      case socket.assigns[:current_scope] do
        %{actor: user, tenant: space} when not is_nil(user) and not is_nil(space) ->
          path = url |> URI.parse() |> Map.get(:path, "/")

          _ =
            track_user_presence(user, path, space.id,
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

  @spec track_user_presence(Wik.Accounts.User.t(), String.t(), String.t(), keyword()) ::
          {:ok, map()} | {:error, term()}
  def track_user_presence(user, path, space_id, opts \\ []) do
    meta = build_presence_meta(path, space_id, opts)
    topic = build_space_topic(space_id)

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
        do: Map.get(presence, :display_name) || presence.id
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
              membership: presence.membership,
              user: presence.user,
              user_id: presence.id
            })
          end
      end
    end)
  end

  defp broadcast_proxy_event(topic, event, payload) do
    Phoenix.PubSub.local_broadcast(
      Wik.PubSub,
      build_proxy_topic(topic),
      {__MODULE__, {event, payload}}
    )
  end

  defp present_memberships(memberships_by_user_id) do
    Map.new(memberships_by_user_id, fn {user_id, membership} ->
      {user_id, Accounts.present_membership(membership)}
    end)
  end

  defp normalize_membership(membership, user, user_id) do
    membership
    |> Map.put_new(:user, user)
    |> Map.put_new(:display_name, default_display_name(user, user_id))
  end

  defp default_display_name(%User{} = user, _user_id), do: to_string(user)
  defp default_display_name(_user, user_id), do: user_id

  defp safe_list_users_by_id(user_ids, presentation_by_user_id) do
    list_users_by_id(user_ids, presentation_by_user_id)
  rescue
    _ -> %{}
  catch
    :exit, _ -> %{}
  end

  defp list_users_by_id(user_ids, presentation_by_user_id) do
    loaded_users =
      presentation_by_user_id
      |> Map.values()
      |> Enum.reduce(%{}, fn presentation, users ->
        case presentation.user do
          %User{} = user -> Map.put(users, user.id, user)
          nil -> users
        end
      end)

    missing_user_ids = Enum.reject(user_ids, &Map.has_key?(loaded_users, &1))

    case missing_user_ids do
      [] ->
        loaded_users

      _user_ids ->
        case User
             |> Ash.Query.filter(id in ^missing_user_ids)
             |> Ash.read(authorize?: false) do
          {:ok, fetched_users} ->
            Map.merge(loaded_users, Map.new(fetched_users, &{&1.id, &1}))

          {:error, _error} ->
            loaded_users
        end
    end
  end

  defp fetch_memberships_by_user_id(space_id, user_ids) do
    case Accounts.list_memberships_by_user_id(space_id, user_ids) do
      {:ok, memberships} -> memberships
      {:error, _error} -> %{}
    end
  rescue
    _ -> %{}
  catch
    :exit, _ -> %{}
  end

  defp build_presence_meta(path, space_id, opts) do
    %{
      editing_block_id: Keyword.get(opts, :editing_block_id),
      space_id: space_id,
      tab_id: Keyword.get(opts, :tab_id),
      path: path
    }
  end

  defp build_space_topic(space_id), do: "space:#{space_id}:users"

  defp build_proxy_topic(topic), do: "proxy:#{topic}"

  defp space_id_from_topic("space:" <> rest) do
    rest |> String.replace_suffix(":users", "")
  end

  defp space_id_from_topic(_topic), do: nil

  defp presence_sort_key(%{user: user}) when not is_nil(user), do: to_string(user)
  defp presence_sort_key(%{id: id}), do: id
end
