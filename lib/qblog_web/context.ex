defmodule QblogWeb.Context do
  @moduledoc """
  Builds and refreshes app-wide UI context for LiveViews.
  """

  alias Qblog.Access
  alias Qblog.Accounts.User

  def build(nil), do: %{claimable_sources: []}

  def build(%User{} = user) do
    %{
      claimable_sources: list_claimable_sources(user)
    }
  end

  def subscribe(nil), do: :ok

  def subscribe(%User{id: user_id}) do
    Phoenix.PubSub.subscribe(Qblog.PubSub, topic(user_id))
  end

  def subscribe_to_membership_changed(nil), do: :ok

  def subscribe_to_membership_changed(%User{id: user_id}) do
    Phoenix.PubSub.subscribe(Qblog.PubSub, membership_changed_topic(user_id))
  end

  def broadcast_claimable_sources_changed(user_id) when is_binary(user_id) do
    Phoenix.PubSub.broadcast(
      Qblog.PubSub,
      topic(user_id),
      {__MODULE__, :claimable_sources_changed}
    )
  end

  def broadcast_membership_changed(user_id) when is_binary(user_id) do
    Phoenix.PubSub.broadcast(
      Qblog.PubSub,
      membership_changed_topic(user_id),
      {__MODULE__, :membership_changed}
    )
  end

  defp topic(user_id), do: "user:#{user_id}:context"
  defp membership_changed_topic(user_id), do: "user:#{user_id}:membership_changed"

  defp list_claimable_sources(user) do
    case Access.telegram_list_claimable_sources(user) do
      sources when is_list(sources) -> sources
      {:error, _error} -> []
    end
  end
end
