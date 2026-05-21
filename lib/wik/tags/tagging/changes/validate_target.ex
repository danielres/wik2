defmodule Wik.Tags.Tagging.Changes.ValidateTarget do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Ash.Query
  alias Wik.Accounts
  alias Wik.Accounts.Membership

  require Ash.Query

  @supported_taggable_types ["membership"]

  @impl true
  def change(changeset, _opts, _context) do
    space_id = Changeset.get_attribute(changeset, :space_id)
    taggable_type = Changeset.get_argument_or_attribute(changeset, :taggable_type)
    taggable_id = Changeset.get_argument_or_attribute(changeset, :taggable_id)

    case validate_target(space_id, taggable_type, taggable_id) do
      :ok ->
        changeset

      {:error, field, message} ->
        Changeset.add_error(changeset, field: field, message: message)
    end
  end

  defp validate_target(nil, _taggable_type, _taggable_id),
    do: {:error, :space_id, "is required"}

  defp validate_target(_space_id, taggable_type, _taggable_id)
       when taggable_type not in @supported_taggable_types,
       do: {:error, :taggable_type, "is not supported"}

  defp validate_target(space_id, "membership", taggable_id) do
    query =
      Membership
      |> Query.filter(space_id == ^space_id and id == ^taggable_id)

    if Ash.exists?(query, authorize?: false, domain: Accounts) do
      :ok
    else
      {:error, :taggable_id, "does not match a membership in this space"}
    end
  end
end
