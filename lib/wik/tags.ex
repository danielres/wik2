defmodule Wik.Tags do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Ash.Query
  alias Utils.Log
  alias Wik.Accounts.Group
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Wiki.PageTree.Wikilinks
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge
  alias Wik.Tags.Tagging

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Tag do
      define :create_tag, action: :create, args: [:slug, :name, :description]
      define :get_tag, action: :read, get_by: [:id]
    end

    resource TagEdge
    resource Tagging
  end

  def update_tag(%Tag{} = tag, attrs, opts \\ []) do
    Ash.update(tag, attrs, opts)
  end

  def destroy_tag(tag_or_id, opts \\ [])

  def destroy_tag(%Tag{} = tag, opts) do
    with :ok <- Ash.destroy(tag, opts) do
      {:ok, tag}
    end
  end

  def destroy_tag(tag_id, opts) when is_binary(tag_id) do
    with {:ok, %Tag{} = tag} <- get_tag(tag_id, opts) do
      destroy_tag(tag, opts)
    end
  end

  def list_root_tags(opts) do
    opts
    |> Keyword.fetch!(:scope)
    |> GraphQueries.load_graph()
    |> Map.fetch!(:root_tags)
    |> then(&{:ok, &1})
  rescue
    error ->
      {:error, error}
  end

  def get_tag_by_slug(slug, opts \\ []) when is_binary(slug) do
    scope = Keyword.fetch!(opts, :scope)

    Tag
    |> Query.filter(slug == ^slug)
    |> Ash.read_one(scope: scope)
  end

  def link_tags(parent_tag_id, child_tag_id, opts \\ []) do
    Ash.create(
      TagEdge,
      %{parent_tag_id: parent_tag_id, child_tag_id: child_tag_id},
      Keyword.put(opts, :action, :create)
    )
  end

  def unlink_tags(parent_tag_id, child_tag_id, opts \\ []) do
    scope = Keyword.fetch!(opts, :scope)

    TagEdge
    |> Query.filter(parent_tag_id == ^parent_tag_id and child_tag_id == ^child_tag_id)
    |> Ash.read_one(scope: scope)
    |> case do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, %TagEdge{} = edge} ->
        with :ok <- Ash.destroy(edge, opts) do
          {:ok, edge}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def list_tag_children(tag_or_id, opts \\ []) do
    opts
    |> Keyword.fetch!(:scope)
    |> GraphQueries.load_graph()
    |> GraphQueries.children_for(tag_or_id)
    |> then(&{:ok, &1})
  rescue
    error ->
      {:error, error}
  end

  def list_tag_parents(tag_or_id, opts \\ []) do
    opts
    |> Keyword.fetch!(:scope)
    |> GraphQueries.load_graph()
    |> GraphQueries.parents_for(tag_or_id)
    |> then(&{:ok, &1})
  rescue
    error ->
      {:error, error}
  end

  def list_tag_ancestors(tag_or_id, opts \\ []) do
    opts
    |> Keyword.fetch!(:scope)
    |> GraphQueries.list_ancestors(tag_or_id)
    |> then(&{:ok, &1})
  rescue
    error ->
      {:error, error}
  end

  def list_tag_descendants(tag_or_id, opts \\ []) do
    opts
    |> Keyword.fetch!(:scope)
    |> GraphQueries.list_descendants(tag_or_id)
    |> then(&{:ok, &1})
  rescue
    error ->
      {:error, error}
  end

  def load_tag_graph(scope) do
    GraphQueries.load_graph(scope)
  rescue
    error ->
      Log.scoped_error(scope, error, "tag graph load failed; falling back to empty graph")
      GraphQueries.empty_graph()
  end

  def list_taggings_for(taggable_type, taggable_id, opts \\ []) do
    scope = Keyword.fetch!(opts, :scope)

    taggings_query_for(taggable_type, taggable_id)
    |> Ash.read(scope: scope)
  end

  def upsert_tagging(
        taggable_type,
        taggable_id,
        tagged_by_group_user_relation_id,
        tag_id,
        attrs,
        opts \\ []
      ) do
    scope = Keyword.fetch!(opts, :scope)

    attrs =
      tagging_identity_attrs(
        taggable_type,
        taggable_id,
        tagged_by_group_user_relation_id,
        tag_id
      )
      |> Map.merge(attrs)

    case get_tagging_by_identity(attrs, scope) do
      {:ok, nil} ->
        Ash.create(
          Tagging,
          attrs,
          Keyword.put(opts, :action, :create)
        )

      {:ok, %Tagging{} = tagging} ->
        Ash.update(
          tagging,
          Map.take(attrs, [:dimensions, :description]),
          Keyword.put(opts, :action, :update_details)
        )

      {:error, error} ->
        {:error, error}
    end
  end

  def remove_tagging(
        taggable_type,
        taggable_id,
        tagged_by_group_user_relation_id,
        tag_id,
        opts \\ []
      ) do
    scope = Keyword.fetch!(opts, :scope)

    attrs =
      tagging_identity_attrs(
        taggable_type,
        taggable_id,
        tagged_by_group_user_relation_id,
        tag_id
      )

    case get_tagging_by_identity(attrs, scope) do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, %Tagging{} = tagging} ->
        with :ok <- Ash.destroy(tagging, opts) do
          {:ok, tagging}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  def list_membership_taggings(%GroupUserRelation{} = membership, opts \\ []) do
    list_taggings_for("group_user_relation", membership.id, opts)
  end

  def membership_taggings_query(%GroupUserRelation{} = membership) do
    taggings_query_for("group_user_relation", membership.id)
  end

  def tag_taggings_query(%Tag{} = tag) do
    Tagging
    |> Query.filter(tag_id == ^tag.id and taggable_type == "group_user_relation")
    |> Query.load([:tag, target_membership: [:avatar_url, :user]])
    |> Query.sort(interest_level: :desc, skill_level: :desc)
  end

  def list_group_tags(scope) do
    Tag
    |> Query.sort(name: :asc)
    |> Ash.read(scope: scope)
  end

  def tag_id_to_name_map(group_id) when is_binary(group_id) do
    group_id
    |> tags_with_names()
    |> Wikilinks.tag_ids_to_tag_names_map()
  end

  def tag_id_to_name_map(_group_id), do: %{}

  def tag_name_to_id_map(group_id) when is_binary(group_id) do
    group_id
    |> tags_with_names()
    |> Wikilinks.tag_names_to_tag_id_map()
  end

  def tag_name_to_id_map(_group_id), do: %{}

  def tag_name_to_slug_map(group_id) when is_binary(group_id) do
    group_id
    |> tags_with_names()
    |> Wikilinks.tag_names_to_slug_map()
  end

  def tag_name_to_slug_map(_group_id), do: %{}

  def upsert_membership_tagging(%GroupUserRelation{} = membership, tag_id, attrs, opts \\ []) do
    upsert_tagging(
      "group_user_relation",
      membership.id,
      membership.id,
      tag_id,
      attrs,
      opts
    )
  end

  def remove_membership_tagging(%GroupUserRelation{} = membership, tag_id, opts \\ []) do
    remove_tagging(
      "group_user_relation",
      membership.id,
      membership.id,
      tag_id,
      opts
    )
  end

  defp get_tagging_by_identity(attrs, scope) do
    %{tag_id: tag_id, tagged_by_group_user_relation_id: author_id} = attrs

    Tagging
    |> Query.filter(
      taggable_type == ^attrs.taggable_type and
        taggable_id == ^attrs.taggable_id and
        tagged_by_group_user_relation_id == ^author_id and
        tag_id == ^tag_id
    )
    |> Ash.read_one(scope: scope)
  end

  defp tagging_identity_attrs(
         taggable_type,
         taggable_id,
         tagged_by_group_user_relation_id,
         tag_id
       ) do
    %{
      tag_id: tag_id,
      taggable_id: taggable_id,
      taggable_type: taggable_type,
      tagged_by_group_user_relation_id: tagged_by_group_user_relation_id
    }
  end

  defp taggings_query_for(taggable_type, taggable_id) do
    Tagging
    |> Query.filter(taggable_type == ^taggable_type and taggable_id == ^taggable_id)
    |> Query.load([:tag, :tagged_by_group_user_relation])
    |> Query.sort(interest_level: :desc, skill_level: :desc)
  end

  defp tags_with_names(group_id) do
    group =
      Group
      |> Query.filter(id == ^group_id)
      |> Ash.read_one!(authorize?: false, domain: Wik.Accounts)

    Tag
    |> Query.filter(group_id == ^group_id and not is_nil(name))
    |> Query.sort(name: :asc)
    |> Ash.read!(authorize?: false, domain: __MODULE__, tenant: group)
  end
end
