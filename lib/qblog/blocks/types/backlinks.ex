defmodule Qblog.Blocks.Types.Backlinks do
  @behaviour Qblog.Blocks.Types.Behaviour

  def label, do: "Backlinks"
  def type, do: :backlinks
  def supports_title?, do: true
  def default_data, do: %{"title" => "Backlinks"}

  def block_to_form_params(%{data: %{"title" => title}}, _params, _page_tree) do
    %{"title" => title}
  end

  def update_block(block, params, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    block
    |> Ash.update(
      %{data: %{"title" => params["title"]}},
      opts |> Keyword.put(:action, :update)
    )
  end

  def validate_data(%{"title" => title}) when is_binary(title), do: :ok

  def validate_data(_data) do
    {:error, field: :data, message: "backlinks blocks only accept a title"}
  end
end
