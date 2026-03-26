defmodule QblogWeb.PageTreeLive.PageTreeEditor.AddChildFlow do
  import Phoenix.Component, only: [to_form: 1]

  alias AshPhoenix.Form
  alias Qblog.Wiki.PageTree

  defstruct open?: false, parent_id: nil, form: nil

  def init(scope) do
    form = PageTree.Node |> Form.for_create(:create, scope: scope) |> to_form()
    %__MODULE__{ form: form }
  end

  def open(flow, parent_id) do
    parent_id = parse_optional_node_id(parent_id)
    %{flow | parent_id: parent_id, open?: true}
  end

  def validate(flow, params) do
    %{flow | form: flow.form |> Form.validate(params)}
  end

  def submit(
        flow,
        page_tree,
        %{"form" => %{"parent_id" => parent_id, "slug" => slug, "title" => title} = params},
        scope
      ) do
    parent_id = parse_optional_node_id(parent_id)

    case PageTree.add_child(page_tree, parent_id, slug, title, scope: scope) do
      {:ok, page_tree} ->
        {:ok, init(scope), page_tree}

      {:error, err} ->
        {:error, flow |> with_error(params, err), err}
    end
  end

  defp with_error(flow, params, err) do
    form =
      flow.form
      |> Form.validate(params)
      |> Form.add_error(err)

    %{flow | form: form}
  end

  defp parse_optional_node_id(""), do: nil
  defp parse_optional_node_id(value), do: value |> String.to_integer()
end
