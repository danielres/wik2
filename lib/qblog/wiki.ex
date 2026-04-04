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

  admin do
    show? true
  end

  resources do
    resource Qblog.Wiki.Page
    resource Qblog.Wiki.PageTree
  end

  def load_page_tree(scope) do
    case PageTree.ensure_page_tree(scope: scope) do
      {:ok, page_tree} ->
        page_tree

      {:error, err} ->
        Log.scoped_error(scope, err, "ensure_page_tree failed")
        %PageTree{nodes: []}
    end
  end

  def load_or_create_node_and_page_at_path(path, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])
    title = Keyword.get(opts, :title)
    node = scope |> TreeQueries.load_node_by_path(path)

    case {node, title} do
      {nil, nil} ->
        {nil, nil}

      {nil, title} ->
        case path |> create_page_and_node_at_path(title, scope: scope, load: load) do
          {:ok, node, page} ->
            {node, page}

          {:error, error} ->
            Utils.Log.scoped_error(scope, error, "load_or_create_node_and_page_at_path failed")
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
           with {:ok, page} <- Page.create_page(scope: scope),
                {:ok, page_tree} <- PageTree.ensure_page_tree(scope: scope),
                {:ok, _page_tree} <-
                  PageTree.create_node_at_path(page_tree, path, title, page.id, scope: scope) do
             page
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, page} ->
        node = scope |> TreeQueries.load_node_by_path(path)

        case page |> Ash.load(load, scope: scope) do
          {:ok, page} -> {:ok, node, page}
          {:error, error} -> {:error, error}
        end

      {:error, error} ->
        {:error, error}
    end
  end
end
