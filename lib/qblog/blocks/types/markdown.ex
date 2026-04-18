defmodule Qblog.Blocks.Types.Markdown do
  def label, do: "Markdown"
  def type, do: :markdown

  def block_to_form_params(block), do: block |> block_to_form_params(%{})

  def block_to_form_params(block, params) do
    %{"text" => params["text"] || block.data |> get_text() || ""}
  end

  def update_block(block, params, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    block
    |> Ash.update(
      %{data: %{"text" => params["text"] || ""}},
      opts |> Keyword.put(:action, :update)
    )
  end

  def validate_data(data) do
    text = data |> get_text()

    case text do
      nil ->
        :ok

      text when is_binary(text) ->
        :ok

      _ ->
        {:error, field: :data, message: "markdown blocks must store text as a string"}
    end
  end

  defp get_text(%{"text" => text}), do: text
  defp get_text(_), do: nil
end
