defmodule Qblog.Accounts.User.Changes.MakeFirstUserSuperadmin do
  @moduledoc """
  A change that sets the role of the very first user to :superadmin.
  """

  use Ash.Resource.Change
  alias Qblog.Accounts.User

  @impl true
  def change(changeset, _opts, _context) do
    if User |> Ash.count!(authorize?: false) == 0 do
      Ash.Changeset.force_change_attribute(changeset, :role, :superadmin)
    else
      changeset
    end
  end
end
