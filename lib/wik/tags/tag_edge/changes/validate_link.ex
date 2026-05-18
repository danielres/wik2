defmodule Wik.Tags.TagEdge.Changes.ValidateLink do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Wik.Tags.GraphRules

  @impl true
  def change(changeset, _opts, _context) do
    group_id = Changeset.get_attribute(changeset, :group_id)
    parent_tag_id = Changeset.get_attribute(changeset, :parent_tag_id)
    child_tag_id = Changeset.get_attribute(changeset, :child_tag_id)

    case GraphRules.validate_link(group_id, parent_tag_id, child_tag_id) do
      :ok ->
        changeset

      {:error, field, message} ->
        Changeset.add_error(changeset, field: field, message: message)
    end
  end
end
