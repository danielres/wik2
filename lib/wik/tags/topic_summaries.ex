defmodule Wik.Tags.TopicSummaries do
  @moduledoc """
  Shared helpers for building topic summary structs from a list of taggings.

  A topic summary groups all taggings for a given tag, computing an average
  relevancy level, a count, and optionally identifying the current member's own
  tagging.
  """

  alias Wik.Tags.Tagging

  @doc """
  Builds a sorted list of topic summary maps from `taggings`.

  Each summary has the shape:

      %{
        average_relevancy: integer() | nil,
        count: non_neg_integer(),
        current_member_tagging: Tagging.t() | nil,
        tag: Tag.t(),
        taggings: [Tagging.t()]
      }

  When `current_membership` is `nil` (the default), `current_member_tagging`
  is always `nil`.
  """
  def build(taggings, current_membership \\ nil) do
    taggings
    |> Enum.group_by(& &1.tag_id)
    |> Enum.map(fn {_tag_id, taggings} ->
      tag = taggings |> List.first() |> Map.get(:tag)
      relevancy_levels = Enum.map(taggings, &dimension_level(&1, "relevancy"))

      %{
        average_relevancy: average_level(relevancy_levels),
        count: length(taggings),
        current_member_tagging: current_member_tagging(taggings, current_membership),
        tag: tag,
        taggings: sort_taggings(taggings, current_membership)
      }
    end)
    |> Enum.reject(&is_nil(&1.tag))
    |> Enum.sort_by(fn summary ->
      {
        -(summary.average_relevancy || 0),
        String.downcase(summary.tag.name || "")
      }
    end)
  end

  @doc "Returns the value of a named dimension from a tagging, or `nil`."
  def dimension_level(%Tagging{dimensions: dimensions}, key) when is_map(dimensions) do
    Map.get(dimensions, key)
  end

  def dimension_level(_tagging, _key), do: nil

  @doc "Returns the rounded average of a list of integer levels, ignoring nils."
  def average_level(levels) do
    levels = Enum.reject(levels, &is_nil/1)

    case levels do
      [] -> nil
      levels -> round(Enum.sum(levels) / length(levels))
    end
  end

  defp current_member_tagging(_taggings, nil), do: nil

  defp current_member_tagging(taggings, membership) do
    Enum.find(taggings, &(&1.tagged_by_membership_id == membership.id))
  end

  defp sort_taggings(taggings, nil), do: taggings

  defp sort_taggings(taggings, membership) do
    Enum.sort_by(taggings, fn tagging ->
      {tagging.tagged_by_membership_id != membership.id,
       -(dimension_level(tagging, "relevancy") || 0)}
    end)
  end
end
