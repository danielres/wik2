defmodule Wik.Wiki do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Wik.Repo
  alias Wik.Wiki.Page
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Node
  alias Utils.Log

  require Ash.Query

  admin do
    show? true
  end

  resources do
    resource Wik.Wiki.Page
    resource Wik.Wiki.PageTree
  end

  def load_page_tree(scope) do
    case PageTree.ensure(scope: scope) do
      {:ok, page_tree} ->
        page_tree

      {:error, err} ->
        Log.scoped_error(scope, err, "PageTree.ensure failed; falling back to empty page tree")
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
    title_path = Keyword.get(opts, :title_path)
    {node, page} = path |> load_page_and_node_by_path(scope: scope, load: load)

    case {node, page} do
      {node, page} when not is_nil(page) ->
        {:ok, node, page}

      {nil, nil} ->
        path
        |> create_page_and_node_at_path(path_to_default_page_title(path),
          scope: scope,
          load: load,
          title_path: title_path
        )

      {node, nil} ->
        node |> create_page_for_existing_node(scope: scope, load: load)
    end
  end

  def load_node_by_path(scope, path) do
    page_tree = scope |> load_page_tree()

    case PageTree.get_node_by_path(page_tree.nodes, path) do
      {:ok, node} -> node
      {:error, _error} -> nil
    end
  end

  defp create_page_and_node_at_path(path, title, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])
    title_segments = opts |> Keyword.get(:title_path) |> parse_title_path()

    case Repo.transaction(fn ->
           with {:ok, page, page_notifications} <-
                  Page.create(scope: scope, return_notifications?: true),
                {:ok, page_tree} <- PageTree.ensure(scope: scope),
                {:ok, _page_tree, page_tree_notifications} <-
                  PageTree.create_node_at_path(
                    page_tree,
                    path,
                    title,
                    page.id,
                    title_segments,
                    scope: scope,
                    return_notifications?: true
                  ) do
             {page, page_notifications ++ page_tree_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {page, notifications}} ->
        Ash.Notifier.notify(notifications)
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
           with {:ok, page, page_notifications} <-
                  Page.create(scope: scope, return_notifications?: true),
                {:ok, page_tree} <- PageTree.ensure(scope: scope),
                {:ok, _page_tree, page_tree_notifications} <-
                  PageTree.link_page(
                    page_tree,
                    node.id,
                    page.id,
                    scope: scope,
                    return_notifications?: true
                  ) do
             {page, page_notifications ++ page_tree_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {page, notifications}} ->
        Ash.Notifier.notify(notifications)

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

  defp parse_title_path(nil), do: nil

  defp parse_title_path(title_path) when is_binary(title_path) do
    title_path
    |> String.split("/", trim: true)
    |> Enum.map(&String.trim/1)
    |> then(fn segments ->
      if segments == [] or Enum.any?(segments, &(&1 == "")), do: nil, else: segments
    end)
  end
end
