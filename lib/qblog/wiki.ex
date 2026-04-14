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

  def ensure_node_and_page_at_path(path, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])
    title = path |> default_page_title_from_path()
    node = scope |> load_node_by_path(path)

    case {node, title} do
      {nil, title} ->
        case path |> create_page_and_node_at_path(title, scope: scope, load: load) do
          {:ok, node, page} ->
            {node, page}

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "create_page_and_node_at_path failed")
            {nil, nil}
        end

      {node, _title} ->
        page = scope |> Node.load_or_create_page(node, load: load)
        {node, page}
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

  def load_node_by_path(scope, path) do
    page_tree = scope |> load_page_tree()

    case TreeQueries.get_node_by_path(page_tree.nodes, path) do
      {:ok, node} -> node
      {:error, _error} -> nil
    end
  end

  # TODO: rename to "_to_" convention: path_to_default_page_title
  defp default_page_title_from_path(path) do
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
