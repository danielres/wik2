defmodule WikWeb.Context do
  @moduledoc """
  Builds and refreshes app-wide UI context for LiveViews.
  """

  alias Wik.Access
  alias Wik.Accounts.User

  def build(nil), do: %{claimable_sources: []}

  def build(%User{} = user) do
    %{
      claimable_sources: list_claimable_sources(user)
    }
  end

  def subscribe(nil), do: :ok

  def subscribe(%User{id: user_id}) do
    Phoenix.PubSub.subscribe(Wik.PubSub, topic(user_id))
  end

  def broadcast_claimable_sources_changed(user_id) when is_binary(user_id) do
    Phoenix.PubSub.broadcast(
      Wik.PubSub,
      topic(user_id),
      {__MODULE__, :claimable_sources_changed}
    )
  end

  defp topic(user_id), do: "user:#{user_id}:context"

  defp list_claimable_sources(user) do
    case Access.telegram_list_claimable_sources(user) do
      sources when is_list(sources) -> sources
      {:error, _error} -> []
    end
  end
end
