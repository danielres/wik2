defmodule WikWeb.Components.Page.RenameFormState do
  import Phoenix.Component, only: [to_form: 1]

  alias AshPhoenix.Form
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.Node

  defstruct form: nil, node_id: nil

  def init, do: %__MODULE__{}

  def open(node, scope) do
    form =
      Node
      |> Form.for_create(:create,
        params: %{"slug" => node.slug, "title" => node.title},
        scope: scope
      )
      |> to_form()

    %__MODULE__{form: form, node_id: node.id}
  end

  def validate(state, params) do
    %{state | form: Form.validate(state.form, params)}
  end

  def submit(
        state,
        page_tree,
        %{"slug" => slug, "title" => title} = params,
        scope
      ) do
    case PageTree.rename_node(page_tree, state.node_id, slug, title, scope: scope) do
      {:ok, page_tree} ->
        {:ok, init(), page_tree}

      {:error, error} ->
        form =
          state.form
          |> Form.validate(params)
          |> Form.add_error(error)

        {:error, %{state | form: form}, error}
    end
  end
end
