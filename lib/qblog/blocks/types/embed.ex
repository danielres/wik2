defmodule Qblog.Blocks.Types.Embed do
  alias Qblog.Blocks.Types.GoogleCalendar
  alias Qblog.Blocks.Types.GoogleMaps
  alias Qblog.Blocks.Types.SoundCloud
  alias Qblog.Blocks.Types.YouTube

  @modules [YouTube, SoundCloud, GoogleCalendar, GoogleMaps]

  def available do
    @modules
    |> Enum.map(fn module ->
      %{label: module.label(), type: module.type()}
    end)
  end

  def label, do: "Embed"

  def default_data, do: %{"url" => ""}

  def default_type, do: YouTube.type()

  def block_to_form_params(block, params, _page_tree) do
    %{"url" => params["url"] || block.data |> get_url() || ""}
  end

  def update_block(block, params, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    with {:ok, type, url} <- detect_embed(block.type, params["url"]) do
      block
      |> Ash.update(
        %{data: %{"url" => url}, type: type},
        opts |> Keyword.put(:action, :update)
      )
    end
  end

  defp detect_embed(nil, input), do: input |> detect_embed(default_type())

  defp detect_embed(current_type, nil), do: {:ok, current_type, ""}

  defp detect_embed(current_type, input) when is_binary(input) do
    input = input |> String.trim()

    if input == "" do
      {:ok, current_type, ""}
    else
      current_type
      |> modules_for_detection()
      |> Enum.find_value(fn module ->
        case module.normalize_embed_input(input) do
          {:ok, url} when is_binary(url) and url != "" ->
            {:ok, module.type(), url}

          _ ->
            nil
        end
      end)
      |> case do
        nil ->
          {:error, "Embed blocks only accept supported embed URLs or iframe code"}

        result ->
          result
      end
    end
  end

  defp detect_embed(_current_type, _input) do
    {:error, "Embed blocks only accept supported embed URLs or iframe code"}
  end

  defp modules_for_detection(current_type) do
    current_module = @modules |> Enum.find(&(&1.type() == current_type))
    remaining_modules = @modules |> Enum.reject(&(&1 == current_module))

    if current_module == nil do
      @modules
    else
      [current_module | remaining_modules]
    end
  end

  defp get_url(%{"url" => url}), do: url
  defp get_url(_), do: nil
end
