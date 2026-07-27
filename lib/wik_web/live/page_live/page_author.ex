defmodule WikWeb.PageLive.PageAuthor do
  @moduledoc false

  import Phoenix.Component, only: [assign: 3]

  def assign_membership(%{assigns: %{current_scope: scope, page: %{author: author}}} = socket) do
    case Wik.Accounts.get_membership(scope.tenant, author) do
      {:ok, membership} ->
        assign(socket, :author_membership, membership)

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "load_page_author_membership failed")
        assign(socket, :author_membership, nil)
    end
  end

  def assign_membership(socket), do: assign(socket, :author_membership, nil)
end
