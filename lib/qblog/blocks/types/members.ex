defmodule Qblog.Blocks.Types.Members do
  @behaviour Qblog.Blocks.Types.Behaviour

  def label, do: "Members"
  def type, do: :members
  def default_data, do: %{}

  def block_to_form_params(_block, _params, _page_tree), do: %{}

  def update_block(block, _params, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    block
    |> Ash.update(
      %{data: %{}},
      opts |> Keyword.put(:action, :update)
    )
  end

  def validate_data(data) when data in [%{}, nil], do: :ok

  def validate_data(_data) do
    {:error, field: :data, message: "members blocks do not accept configuration"}
  end
end
