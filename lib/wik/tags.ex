defmodule Wik.Tags do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Ash.Query
  alias Utils.Log
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge

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
  end

  def update_tag(%Tag{} = tag, attrs, opts \\ []) do
    Ash.update(tag, attrs, Keyword.put_new(opts, :domain, __MODULE__))
  end

  def destroy_tag(tag_or_id, opts \\ [])

  def destroy_tag(%Tag{} = tag, opts) do
    case Ash.destroy(tag, Keyword.put_new(opts, :domain, __MODULE__)) do
      :ok -> {:ok, tag}
      {:ok, _destroyed_tag} -> {:ok, tag}
      {:error, error} -> {:error, error}
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
    |> Ash.read_one(scope: scope, domain: __MODULE__)
  end

  def link_tags(parent_tag_id, child_tag_id, opts \\ []) do
    Ash.create(
      TagEdge,
      %{parent_tag_id: parent_tag_id, child_tag_id: child_tag_id},
      opts
      |> Keyword.put_new(:domain, __MODULE__)
      |> Keyword.put(:action, :create)
    )
  end

  def unlink_tags(parent_tag_id, child_tag_id, opts \\ []) do
    scope = Keyword.fetch!(opts, :scope)

    TagEdge
    |> Query.filter(parent_tag_id == ^parent_tag_id and child_tag_id == ^child_tag_id)
    |> Ash.read_one(scope: scope, domain: __MODULE__)
    |> case do
      {:ok, nil} ->
        {:error, :not_found}

      {:ok, %TagEdge{} = edge} ->
        case Ash.destroy(edge, Keyword.put_new(opts, :domain, __MODULE__)) do
          :ok -> {:ok, edge}
          {:ok, _destroyed_edge} -> {:ok, edge}
          {:error, error} -> {:error, error}
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
end
