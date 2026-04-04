defmodule Qblog.Wiki.PageTree.Node.Helpers do
  alias Qblog.Wiki
  alias Utils.Log

  def path_to_default_title(path) do
    path
    |> String.split("/", trim: true)
    |> List.last()
    |> case do
      nil ->
        ""

      slug ->
        slug |> String.split("-") |> Enum.map_join(" ", &String.capitalize/1)
    end
  end

  def get_or_create_page(scope, node, opts \\ [])

  def get_or_create_page(_scope, nil, _opts), do: {:ok, nil}

  def get_or_create_page(scope, %{page_id: nil} = node, opts) do
    load = opts |> Keyword.get(:load, [])

    with {:ok, page} <- node |> Wiki.create_page_for_node(scope: scope),
         {:ok, page} <- page |> Ash.load(load, scope: scope) do
      {:ok, page}
    end
  end

  def get_or_create_page(scope, %{page_id: page_id}, opts) do
    load = opts |> Keyword.get(:load, [])
    Wiki.get_page(page_id, load: load, scope: scope)
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
end
