defmodule Wik.Blocks.Types.Text do
  @behaviour Wik.Blocks.Types.Behaviour

  def label, do: "Text"
  def type, do: :text
  def supports_history?, do: false
  def supports_title?, do: false
  def default_data, do: %{"text" => ""}
  def create_initial_version(_block, _opts), do: :ok

  def block_to_form_params(%{data: %{"text" => text}}, _params, _page_tree) do
    %{"text" => text}
  end

  def update_block(block, %{"text" => text}, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    block
    |> Ash.update(
      %{data: %{"text" => text}},
      opts |> Keyword.put(:action, :update)
    )
  end

  def version_to_text(_block, _version, _opts), do: {:error, :unsupported}

  def validate_data(%{"text" => text}) when is_binary(text), do: :ok

  def validate_data(_data) do
    {:error, field: :data, message: "text blocks must store text as a string"}
  end
end
