defmodule Wik.Accounts.GroupUserRelation.Changes.SetUsername do
  use Ash.Resource.Change

  alias Ash.Changeset

  def change(changeset, _opts, _context) do
    username = Changeset.get_argument_or_attribute(changeset, :username)
    existing_username = Changeset.get_data(changeset, :username)

    cond do
      is_binary(existing_username) and existing_username != "" ->
        Changeset.add_error(changeset, field: :username, message: "has already been set")

      not is_binary(username) or username == "" ->
        Changeset.add_error(changeset, field: :username, message: "can't be blank")

      true ->
        changeset
    end
  end
end
