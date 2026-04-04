defmodule Qblog.Wiki do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Qblog.Repo
  alias Qblog.Wiki.PageTree

  admin do
    show? true
  end

  resources do
    resource Qblog.Wiki.PageTree do
      define :get_page_tree, action: :get_or_create_page_tree, args: []
      define :link_page, action: :link_page, args: [:node_id, :page_id]
      define :create_node_at_path, action: :create_node_at_path, args: [:path, :title, :page_id]
    end

    resource Qblog.Wiki.Page do
      define :get_page, action: :read, get_by: [:id]
      define :create_page, action: :create, args: []
    end
  end

  def create_page_for_node(node, opts) do
    scope = Keyword.fetch!(opts, :scope)

    Repo.transaction(fn ->
      with {:ok, page} <- create_page(scope: scope),
           {:ok, page_tree} <- get_page_tree(scope: scope),
           {:ok, _page_tree} <- PageTree.link_page(page_tree, node.id, page.id, scope: scope) do
        page
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end

  def create_page_at_path(path, title, opts) do
    scope = Keyword.fetch!(opts, :scope)

    Repo.transaction(fn ->
      with {:ok, page} <- create_page(scope: scope),
           {:ok, page_tree} <- get_page_tree(scope: scope),
           {:ok, _page_tree} <-
             PageTree.create_node_at_path(page_tree, path, title, page.id, scope: scope) do
        page
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
  end
end
