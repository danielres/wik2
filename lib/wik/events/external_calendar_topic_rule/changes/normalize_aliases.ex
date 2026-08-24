defmodule Wik.Events.ExternalCalendarTopicRule.Changes.NormalizeAliases do
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    aliases =
      changeset
      |> Ash.Changeset.get_attribute(:aliases)
      |> normalize_aliases()

    Ash.Changeset.force_change_attribute(changeset, :aliases, aliases)
  end

  defp normalize_aliases(nil), do: []

  defp normalize_aliases(aliases) do
    aliases
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq_by(&String.downcase/1)
  end
end
