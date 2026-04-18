defmodule Qblog.Blocks.Types.Members do
  def label, do: "Members"
  def type, do: :members

  def block_to_form_params(_block), do: %{}
  def block_to_form_params(_block, _params), do: %{}

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
