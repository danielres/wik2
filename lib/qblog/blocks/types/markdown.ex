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
      %{data: %{"text" => params |> get_text() |> normalize_text()}},
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

  defp normalize_text(text) when is_binary(text) do
    text
    |> normalize_line_endings()
    |> trim_trailing_spaces_per_line()
    |> String.trim()
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  defp normalize_text(_text), do: ""

  defp normalize_line_endings(text) do
    String.replace(text, ~r/\r\n?/, "\n")
  end

  defp trim_trailing_spaces_per_line(text) do
    text
    |> String.split("\n")
    |> Enum.map(&String.trim_trailing/1)
    |> Enum.join("\n")
  end
end
