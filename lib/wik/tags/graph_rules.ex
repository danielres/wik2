defmodule Wik.Tags.GraphRules do
  import Ecto.Query

  alias Wik.Repo
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag

  def validate_link(group_id, parent_tag_id, child_tag_id)
      when is_binary(group_id) and is_binary(parent_tag_id) and is_binary(child_tag_id) do
    cond do
      parent_tag_id == child_tag_id ->
        {:error, :child_tag_id, "cannot link a tag to itself"}

      not tags_belong_to_group?(group_id, [parent_tag_id, child_tag_id]) ->
        {:error, :child_tag_id, "tags must belong to the current group"}

      GraphQueries.path_exists?(group_id, child_tag_id, parent_tag_id) ->
        {:error, :child_tag_id, "cannot create a cycle"}

      true ->
        :ok
    end
  end

  def validate_link(_group_id, _parent_tag_id, _child_tag_id),
    do: {:error, :child_tag_id, "is invalid"}

  defp tags_belong_to_group?(group_id, tag_ids) do
    tag_ids =
      tag_ids
      |> Enum.filter(&is_binary/1)
      |> Enum.uniq()

    count =
      Tag
      |> where([tag], tag.group_id == ^group_id and tag.id in ^tag_ids)
      |> select([tag], count(tag.id))
      |> Repo.one()

    count == length(tag_ids)
  end
end
