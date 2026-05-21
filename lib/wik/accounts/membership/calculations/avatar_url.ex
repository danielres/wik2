defmodule Wik.Accounts.Membership.Calculations.AvatarUrl do
  use Ash.Resource.Calculation

  alias Wik.Access

  def calculate([], _opts, _context), do: {:ok, []}

  def calculate(records, _opts, _context) do
    with {:ok, avatar_urls_by_space_and_user} <- list_avatar_urls(records) do
      {:ok,
       Enum.map(records, fn record ->
         avatar_urls_by_space_and_user
         |> Map.get(record.space_id, %{})
         |> Map.get(record.user_id)
       end)}
    end
  end

  defp list_avatar_urls(records) do
    records
    |> Enum.group_by(& &1.space_id, & &1.user_id)
    |> Enum.reduce_while({:ok, %{}}, fn {space_id, user_ids}, {:ok, acc} ->
      case Access.list_space_avatar_urls(space_id, user_ids) do
        {:ok, avatar_urls} ->
          {:cont, {:ok, Map.put(acc, space_id, avatar_urls)}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end
end
