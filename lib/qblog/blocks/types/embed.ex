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

  def default_data, do: %{"title" => "", "url" => ""}

  # TODO: remove default_type?
  def default_type, do: YouTube.type()

  def block_to_form_params(%{data: %{"title" => title, "url" => url}}, _params, _page_tree) do
    %{"title" => title, "url" => url}
  end

  def update_block(block, params, opts) do
    _scope = Keyword.fetch!(opts, :scope)

    with {:ok, type, url} <- detect_embed(block.type, params["url"]) do
      block
      |> Ash.update(
        %{data: %{"title" => params["title"], "url" => url}, type: type},
        opts |> Keyword.put(:action, :update)
      )
    end
  end

  def validate_title(%{"title" => title}) when is_binary(title), do: :ok

  def validate_title(_data) do
    {:error, field: :data, message: "block title must be a string"}
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
end
