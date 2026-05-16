defmodule Wik.Accounts.Token.Changes.RevokeCustomToken do
  use Ash.Resource.Change

  alias Ash.Changeset

  @impl true
  def change(changeset, _opts, _context) do
    purpose = Ash.Changeset.get_attribute(changeset, :purpose) || changeset.data.purpose

    extra_data =
      Ash.Changeset.get_attribute(changeset, :extra_data) || changeset.data.extra_data || %{}

    changeset
    |> Changeset.force_change_attribute(:purpose, "revoked:" <> purpose)
    |> Changeset.force_change_attribute(
      :extra_data,
      Map.put(extra_data, "revoked_at", DateTime.utc_now() |> DateTime.to_iso8601())
    )
  end
end
