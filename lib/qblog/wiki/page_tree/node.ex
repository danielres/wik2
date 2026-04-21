defmodule Qblog.Wiki.PageTree.Node do
  use Ash.Resource,
    data_layer: :embedded

  alias Qblog.Wiki
  alias Utils.Log

  @type t :: %__MODULE__{
          id: integer(),
          page_id: String.t() | nil,
          parent_id: integer() | nil,
          slug: String.t(),
          title: String.t()
        }

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

  def load_page(scope, node, opts \\ []) do
    case scope |> get_page(node, opts) do
      {:ok, page} ->
        page

      {:error, error} ->
        Log.scoped_error(scope, error, "get_page failed")
        nil
    end
  end

  defp get_page(_scope, nil, _opts), do: {:ok, nil}

  defp get_page(_scope, %{page_id: nil}, _opts), do: {:ok, nil}

  defp get_page(scope, %{page_id: page_id}, opts) do
    load = opts |> Keyword.get(:load, [])
    Wiki.Page.get_by_id(page_id, load: load, scope: scope)
  end
end
