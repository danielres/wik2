defmodule Qblog.Wiki.PageTree.Node do
  use Ash.Resource,
    data_layer: :embedded

  alias Qblog.Repo
  alias Qblog.Wiki
  alias Utils.Log

  attributes do
    attribute :id, :integer do
      allow_nil? false
      public? true
    end

    attribute :page_id, :uuid do
      allow_nil? true
      public? true
    end

    attribute :parent_id, :integer do
      allow_nil? true
      public? true
    end

    attribute :title, :string do
      allow_nil? false
      public? true
    end

    attribute :slug, :string do
      allow_nil? false
      public? true
    end
  end

  def load_or_create_page(scope, node, opts \\ []) do
    case scope |> get_or_create_page(node, opts) do
      {:ok, page} ->
        page

      {:error, error} ->
        Log.scoped_error(scope, error, "get_or_create_page failed")
        nil
    end
  end

  defp get_or_create_page(_scope, nil, _opts), do: {:ok, nil}

  defp get_or_create_page(scope, %{page_id: nil} = node, opts) do
    load = opts |> Keyword.get(:load, [])

    with {:ok, page} <- node |> create_page_for_node(scope: scope),
         {:ok, page} <- page |> Ash.load(load, scope: scope) do
      {:ok, page}
    end
  end

  defp get_or_create_page(scope, %{page_id: page_id}, opts) do
    load = opts |> Keyword.get(:load, [])
    Wiki.Page.get_by_id(page_id, load: load, scope: scope)
  end

  defp create_page_for_node(node, opts) do
    scope = Keyword.fetch!(opts, :scope)

    Repo.transaction(fn ->
      with {:ok, page} <- Wiki.Page.create(scope: scope),
           {:ok, page_tree} <- Wiki.PageTree.ensure(scope: scope),
           {:ok, _page_tree} <- Wiki.PageTree.link_page(page_tree, node.id, page.id, scope: scope) do
        page
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end
end
