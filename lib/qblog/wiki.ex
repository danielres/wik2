defmodule Qblog.Wiki do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Qblog.Repo
  alias Qblog.Wiki.Page
  alias Qblog.Wiki.PageTree
  alias Qblog.Wiki.PageTree.Node
  alias Qblog.Wiki.PageTree.TreeQueries
  alias Utils.Log

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Qblog.Wiki.Page
    resource Qblog.Wiki.PageTree
  end

  def load_page_tree(scope) do
    case PageTree.ensure(scope: scope) do
      {:ok, page_tree} ->
        page_tree

      {:error, err} ->
        Log.scoped_error(scope, err, "PageTree.ensure failed")
        %PageTree{nodes: []}
    end
  end

  def load_page_and_node_by_path(path, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])
    node = scope |> load_node_by_path(path)
    page = scope |> Node.load_page(node, load: load)
    {node, page}
  end

  def ensure_page_and_node_at_path(path, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])
    {node, page} = path |> load_page_and_node_by_path(scope: scope, load: load)

    case {node, page} do
      {node, page} when not is_nil(page) ->
        {:ok, node, page}

      {nil, nil} ->
        path
        |> create_page_and_node_at_path(path_to_default_page_title(path),
          scope: scope,
          load: load
        )

      {node, nil} ->
        node |> create_page_for_existing_node(scope: scope, load: load)
    end
  end

  def load_node_by_path(scope, path) do
    page_tree = scope |> load_page_tree()

    case TreeQueries.get_node_by_path(page_tree.nodes, path) do
      {:ok, node} -> node
      {:error, _error} -> nil
    end
  end

  defp create_page_and_node_at_path(path, title, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])

    case Repo.transaction(fn ->
           with {:ok, page} <- Page.create(scope: scope),
                {:ok, page_tree} <- PageTree.ensure(scope: scope),
                {:ok, _page_tree} <-
                  PageTree.create_node_at_path(page_tree, path, title, page.id, scope: scope) do
             page
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, page} ->
        node = scope |> load_node_by_path(path)

        case page |> Ash.load(load, scope: scope) do
          {:ok, page} -> {:ok, node, page}
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_page_for_existing_node(node, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])

    case Repo.transaction(fn ->
           with {:ok, page} <- Page.create(scope: scope),
                {:ok, page_tree} <- PageTree.ensure(scope: scope),
                {:ok, _page_tree} <- PageTree.link_page(page_tree, node.id, page.id, scope: scope) do
             page
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, page} ->
        case page |> Ash.load(load, scope: scope) do
          {:ok, page} -> {:ok, node, page}
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp path_to_default_page_title(path) do
    path
    |> String.split("/", trim: true)
    |> List.last()
    |> case do
      nil ->
        ""

      slug ->
        slug |> String.split("-") |> Enum.join(" ") |> String.capitalize()
    end
  end
end
