defmodule Wik.Tags.Tagging.Changes.ValidateTarget do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Ash.Query
  alias Wik.Accounts
  alias Wik.Accounts.GroupUserRelation

  require Ash.Query

  @supported_taggable_types ["group_user_relation"]

  @impl true
  def change(changeset, _opts, _context) do
    group_id = Changeset.get_attribute(changeset, :group_id)
    taggable_type = Changeset.get_argument_or_attribute(changeset, :taggable_type)
    taggable_id = Changeset.get_argument_or_attribute(changeset, :taggable_id)

    case validate_target(group_id, taggable_type, taggable_id) do
      :ok ->
        changeset

      {:error, field, message} ->
        Changeset.add_error(changeset, field: field, message: message)
    end
  end

  defp validate_target(nil, _taggable_type, _taggable_id),
    do: {:error, :group_id, "is required"}

  defp validate_target(_group_id, taggable_type, _taggable_id)
       when taggable_type not in @supported_taggable_types,
       do: {:error, :taggable_type, "is not supported"}

  defp validate_target(group_id, "group_user_relation", taggable_id) do
    query =
      GroupUserRelation
      |> Query.filter(group_id == ^group_id and id == ^taggable_id)

    if Ash.exists?(query, authorize?: false, domain: Accounts) do
      :ok
    else
      {:error, :taggable_id, "does not match a membership in this group"}
    end
  end
end
