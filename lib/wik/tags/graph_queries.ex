defmodule Wik.Tags.GraphQueries do
  alias Ash.Query
  import Ecto.Query

  alias Wik.Repo
  alias Wik.Tags
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge
  alias Wik.Tags.Tagging

  require Ash.Query

  @type graph_node :: %{
          tag: Tag.t(),
          parent: Tag.t() | nil,
          path_ids: [String.t()],
          dom_id: String.t(),
          children: [graph_node()]
        }

  def empty_graph do
    %{
      tags: [],
      edges: [],
      root_tags: [],
      root_tree: [],
      tags_by_id: %{},
      children_by_parent_id: %{},
      parents_by_child_id: %{}
    }
  end

  def load_graph(scope) do
    space_id = tenant_space_id!(scope)
    tagging_stats_by_tag_id = membership_tagging_stats(space_id)

    tags =
      Tag
      |> Query.load(:membership_tagging_count)
      |> Ash.read!(scope: scope, domain: Tags)
      |> Enum.map(fn tag ->
        stats = Map.get(tagging_stats_by_tag_id, tag.id, empty_final_tagging_stats())

        tag
        |> Map.put(:membership_interest_average, stats.interest_average)
        |> Map.put(:membership_skill_average, stats.skill_average)
        |> Map.put(:membership_interest_distribution, stats.interest_distribution)
        |> Map.put(:membership_skill_distribution, stats.skill_distribution)
        |> Map.put(:membership_interest_unspecified_count, stats.interest_unspecified_count)
        |> Map.put(:membership_skill_unspecified_count, stats.skill_unspecified_count)
      end)
      |> sort_tags()

    edges = TagEdge |> Ash.read!(scope: scope, domain: Tags)
    tags_by_id = Map.new(tags, &{&1.id, &1})

    children_by_parent_id =
      edges
      |> Enum.group_by(& &1.parent_tag_id, & &1.child_tag_id)
      |> Map.new(fn {parent_id, child_ids} ->
        children =
          child_ids
          |> Enum.uniq()
          |> Enum.map(&Map.fetch!(tags_by_id, &1))
          |> sort_tags()

        {parent_id, children}
      end)

    parents_by_child_id =
      edges
      |> Enum.group_by(& &1.child_tag_id, & &1.parent_tag_id)
      |> Map.new(fn {child_id, parent_ids} ->
        parents =
          parent_ids
          |> Enum.uniq()
          |> Enum.map(&Map.fetch!(tags_by_id, &1))
          |> sort_tags()

        {child_id, parents}
      end)

    root_tags =
      tags
      |> Enum.reject(&Map.has_key?(parents_by_child_id, &1.id))
      |> sort_tags()

    %{
      tags: tags,
      edges: edges,
      root_tags: root_tags,
      root_tree: build_tree(root_tags, children_by_parent_id),
      tags_by_id: tags_by_id,
      children_by_parent_id: children_by_parent_id,
      parents_by_child_id: parents_by_child_id
    }
  end

  def children_for(graph, tag_or_id) do
    tag_id = tag_id(tag_or_id)
    Map.get(graph.children_by_parent_id, tag_id, [])
  end

  def parents_for(graph, tag_or_id) do
    tag_id = tag_id(tag_or_id)
    Map.get(graph.parents_by_child_id, tag_id, [])
  end

  def descendant_tree(graph, tag_or_id) do
    case Map.get(graph.tags_by_id, tag_id(tag_or_id)) do
      nil -> []
      tag -> build_tree([tag], graph.children_by_parent_id)
    end
  end

  def eligible_child_tags(graph, tag_or_id) do
    current_id = tag_id(tag_or_id)
    existing_child_ids = graph |> children_for(current_id) |> Enum.map(& &1.id) |> MapSet.new()
    ancestor_ids = graph |> ancestors_in_memory(current_id) |> MapSet.new()

    graph.tags
    |> Enum.reject(fn tag ->
      tag.id == current_id or MapSet.member?(existing_child_ids, tag.id) or
        MapSet.member?(ancestor_ids, tag.id)
    end)
    |> sort_tags()
  end

  def eligible_parent_tags(graph, tag_or_id) do
    current_id = tag_id(tag_or_id)
    existing_parent_ids = graph |> parents_for(current_id) |> Enum.map(& &1.id) |> MapSet.new()
    descendant_ids = graph |> descendants_in_memory(current_id) |> MapSet.new()

    graph.tags
    |> Enum.reject(fn tag ->
      tag.id == current_id or MapSet.member?(existing_parent_ids, tag.id) or
        MapSet.member?(descendant_ids, tag.id)
    end)
    |> sort_tags()
  end

  def list_ancestors(scope, tag_or_id) do
    space_id = tenant_space_id!(scope)
    tag_id = tag_id(tag_or_id)

    ancestor_ids =
      space_id
      |> ancestor_rows(tag_id)
      |> Enum.map(fn %{id: id} -> id end)

    fetch_tags_in_order(scope, space_id, ancestor_ids)
  end

  def list_descendants(scope, tag_or_id) do
    space_id = tenant_space_id!(scope)
    tag_id = tag_id(tag_or_id)

    descendant_ids =
      space_id
      |> descendant_rows(tag_id)
      |> Enum.map(fn %{id: id} -> id end)

    fetch_tags_in_order(scope, space_id, descendant_ids)
  end

  def path_exists?(space_id, source_tag_id, target_tag_id) do
    sql = """
    WITH RECURSIVE reachable(tag_id) AS (
      SELECT child_tag_id
      FROM tag_edges
      WHERE space_id = $1 AND parent_tag_id = $2

      UNION

      SELECT edge.child_tag_id
      FROM tag_edges AS edge
      JOIN reachable ON edge.parent_tag_id = reachable.tag_id
      WHERE edge.space_id = $1
    )
    SELECT EXISTS(
      SELECT 1
      FROM reachable
      WHERE tag_id = $3
    )
    """

    %{rows: [[exists?]]} =
      Repo.query!(sql, [
        dump_uuid!(space_id),
        dump_uuid!(source_tag_id),
        dump_uuid!(target_tag_id)
      ])

    exists?
  end

  defp ancestor_rows(space_id, tag_id) do
    sql = """
    WITH RECURSIVE ancestors(tag_id, depth) AS (
      SELECT parent_tag_id, 1
      FROM tag_edges
      WHERE space_id = $1 AND child_tag_id = $2

      UNION

      SELECT edge.parent_tag_id, ancestors.depth + 1
      FROM tag_edges AS edge
      JOIN ancestors ON edge.child_tag_id = ancestors.tag_id
      WHERE edge.space_id = $1
    )
    SELECT tag.id, MIN(ancestors.depth) AS depth
    FROM ancestors
    JOIN tags AS tag ON tag.id = ancestors.tag_id
    WHERE tag.space_id = $1
    GROUP BY tag.id, tag.name
    ORDER BY MIN(ancestors.depth), LOWER(tag.name), tag.id
    """

    %{rows: rows} = Repo.query!(sql, [dump_uuid!(space_id), dump_uuid!(tag_id)])
    Enum.map(rows, fn [id, _depth] -> %{id: load_uuid!(id)} end)
  end

  defp descendant_rows(space_id, tag_id) do
    sql = """
    WITH RECURSIVE descendants(tag_id, depth) AS (
      SELECT child_tag_id, 1
      FROM tag_edges
      WHERE space_id = $1 AND parent_tag_id = $2

      UNION

      SELECT edge.child_tag_id, descendants.depth + 1
      FROM tag_edges AS edge
      JOIN descendants ON edge.parent_tag_id = descendants.tag_id
      WHERE edge.space_id = $1
    )
    SELECT tag.id, MIN(descendants.depth) AS depth
    FROM descendants
    JOIN tags AS tag ON tag.id = descendants.tag_id
    WHERE tag.space_id = $1
    GROUP BY tag.id, tag.name
    ORDER BY MIN(descendants.depth), LOWER(tag.name), tag.id
    """

    %{rows: rows} = Repo.query!(sql, [dump_uuid!(space_id), dump_uuid!(tag_id)])
    Enum.map(rows, fn [id, _depth] -> %{id: load_uuid!(id)} end)
  end

  defp build_tree(tags, children_by_parent_id) do
    Enum.map(tags, fn tag ->
      build_node(tag, nil, [tag.id], children_by_parent_id)
    end)
  end

  defp build_node(tag, parent, path_ids, children_by_parent_id) do
    child_tags = Map.get(children_by_parent_id, tag.id, [])

    %{
      tag: tag,
      parent: parent,
      path_ids: path_ids,
      dom_id: "tag-path-" <> Enum.join(path_ids, "__"),
      children:
        Enum.map(child_tags, fn child_tag ->
          if child_tag.id in path_ids do
            %{
              tag: child_tag,
              parent: tag,
              path_ids: path_ids ++ [child_tag.id],
              dom_id: "tag-path-" <> Enum.join(path_ids ++ [child_tag.id], "__"),
              children: []
            }
          else
            build_node(child_tag, tag, path_ids ++ [child_tag.id], children_by_parent_id)
          end
        end)
    }
  end

  defp ancestors_in_memory(graph, tag_id, acc \\ MapSet.new()) do
    graph
    |> parents_for(tag_id)
    |> Enum.reduce(acc, fn parent, seen ->
      if MapSet.member?(seen, parent.id) do
        seen
      else
        ancestors_in_memory(graph, parent.id, MapSet.put(seen, parent.id))
      end
    end)
  end

  defp descendants_in_memory(graph, tag_id, acc \\ MapSet.new()) do
    graph
    |> children_for(tag_id)
    |> Enum.reduce(acc, fn child, seen ->
      if MapSet.member?(seen, child.id) do
        seen
      else
        descendants_in_memory(graph, child.id, MapSet.put(seen, child.id))
      end
    end)
  end

  defp tenant_space_id!(scope) do
    scope
    |> Ash.Scope.ToOpts.get_tenant()
    |> case do
      {:ok, tenant} -> Wik.Accounts.tenant_to_space_id(tenant)
      _ -> nil
    end
    |> case do
      nil -> raise ArgumentError, "scope tenant is required"
      space_id -> space_id
    end
  end

  defp membership_tagging_stats(space_id) do
    from(tagging in Tagging,
      where: tagging.space_id == ^space_id and tagging.taggable_type == "membership",
      select: %{
        tag_id: tagging.tag_id,
        interest: fragment("coalesce((?->>'interest')::int, 0)", tagging.dimensions),
        skill: fragment("coalesce((?->>'skill')::int, 0)", tagging.dimensions)
      }
    )
    |> Repo.all()
    |> Enum.reduce(%{}, fn row, acc ->
      Map.update(acc, row.tag_id, add_tagging_stats(empty_tagging_stats(), row), fn stats ->
        add_tagging_stats(stats, row)
      end)
    end)
    |> Map.new(fn {tag_id, stats} -> {tag_id, finalize_tagging_stats(stats)} end)
  end

  defp empty_tagging_stats do
    %{
      interest_sum: 0,
      interest_count: 0,
      interest_distribution: empty_distribution(),
      interest_unspecified_count: 0,
      skill_sum: 0,
      skill_count: 0,
      skill_distribution: empty_distribution(),
      skill_unspecified_count: 0
    }
  end

  defp empty_final_tagging_stats do
    %{
      interest_average: nil,
      interest_distribution: empty_distribution(),
      interest_unspecified_count: 0,
      skill_average: nil,
      skill_distribution: empty_distribution(),
      skill_unspecified_count: 0
    }
  end

  defp empty_distribution do
    Map.new(1..10, fn level -> {level, 0} end)
  end

  defp add_tagging_stats(stats, %{interest: interest, skill: skill}) do
    stats
    |> add_dimension_stats(:interest, interest)
    |> add_dimension_stats(:skill, skill)
  end

  defp add_dimension_stats(stats, dimension, 0) do
    Map.update!(stats, :"#{dimension}_unspecified_count", &(&1 + 1))
  end

  defp add_dimension_stats(stats, dimension, level) when level in 1..10 do
    stats
    |> Map.update!(:"#{dimension}_sum", &(&1 + level))
    |> Map.update!(:"#{dimension}_count", &(&1 + 1))
    |> update_in([:"#{dimension}_distribution", level], &(&1 + 1))
  end

  defp finalize_tagging_stats(stats) do
    %{
      interest_average: average(stats.interest_sum, stats.interest_count),
      interest_distribution: stats.interest_distribution,
      interest_unspecified_count: stats.interest_unspecified_count,
      skill_average: average(stats.skill_sum, stats.skill_count),
      skill_distribution: stats.skill_distribution,
      skill_unspecified_count: stats.skill_unspecified_count
    }
  end

  defp average(_sum, 0), do: nil
  defp average(sum, count), do: sum / count

  defp sort_tags(tags) do
    Enum.sort_by(tags, fn tag -> {String.downcase(tag.name), tag.name, tag.id} end)
  end

  defp tag_id(%Tag{id: id}), do: id
  defp tag_id(tag_id) when is_binary(tag_id), do: tag_id

  defp fetch_tags_in_order(_scope, _space_id, []), do: []

  defp fetch_tags_in_order(scope, space_id, tag_ids) do
    tags_by_id =
      Tag
      |> Query.filter(space_id == ^space_id and id in ^tag_ids)
      |> Ash.read!(scope: scope, domain: Tags)
      |> Map.new(&{&1.id, &1})

    Enum.map(tag_ids, &Map.fetch!(tags_by_id, &1))
  end

  defp dump_uuid!(value) do
    case Ecto.UUID.dump(value) do
      {:ok, dumped} -> dumped
      :error -> raise ArgumentError, "expected UUID, got: #{inspect(value)}"
    end
  end

  defp load_uuid!(value) do
    case Ecto.UUID.load(value) do
      {:ok, loaded} -> loaded
      :error -> raise ArgumentError, "expected dumped UUID, got: #{inspect(value)}"
    end
  end
end
