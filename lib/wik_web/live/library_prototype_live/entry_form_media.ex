defmodule WikWeb.LibraryPrototypeLive.EntryFormMedia do
  @moduledoc false

  alias WikWeb.LibraryPrototypeLive.Schema

  defstruct autofill_values: %{},
            error: nil,
            external_metadata: nil,
            loading?: false,
            request: nil

  def reset(external_metadata \\ nil) do
    %__MODULE__{external_metadata: external_metadata}
  end

  def change(state, current_params, incoming_params, target, type) do
    previous_media = media(current_params)
    params = Map.merge(current_params, incoming_params)
    state = track_manual_change(state, target, params)

    if external_media_type?(type) and media(params) != previous_media do
      prepare_resolution(state, params)
    else
      {:ok, params, state}
    end
  end

  def begin_resolution(state, url, request_id) do
    %{state | loading?: true, request: %{id: request_id, url: url}}
  end

  def matching_request?(%__MODULE__{request: %{id: request_id, url: url}}, request_id, params) do
    media(params) == url
  end

  def matching_request?(_state, _request_id, _params), do: false

  def request_id(%__MODULE__{request: %{id: id}}), do: id
  def request_id(_state), do: nil

  def apply_result(state, params, {:ok, metadata}) do
    {params, autofill_values} =
      Enum.reduce(
        [creator: :creator, duration: :duration, notes: :description, title: :title],
        {params, %{}},
        fn {field, metadata_key}, acc ->
          put_autofill_value(acc, Atom.to_string(field), Map.get(metadata, metadata_key))
        end
      )

    state = %{
      state
      | autofill_values: autofill_values,
        error: nil,
        external_metadata: external_media_metadata(metadata, media(params)),
        loading?: false,
        request: nil
    }

    {params, state}
  end

  def apply_result(state, params, {:error, :unsupported_provider}) do
    {params, %{state | loading?: false, request: nil}}
  end

  def apply_result(state, params, {:error, _reason}) do
    {params, %{state | error: "Details couldn't be loaded", loading?: false, request: nil}}
  end

  def fail(state) do
    %{state | error: "Details couldn't be loaded", loading?: false, request: nil}
  end

  defp prepare_resolution(state, params) do
    params = clear_previous_autofill(params, state.autofill_values)
    url = media(params)
    state = reset()

    if url == "", do: {:ok, params, state}, else: {:resolve, params, url, state}
  end

  defp put_autofill_value({params, autofill_values}, _key, nil),
    do: {params, autofill_values}

  defp put_autofill_value({params, autofill_values}, key, value) do
    current_value = Map.get(params, key, "")

    if Schema.blank_value?(current_value) do
      {Map.put(params, key, value), Map.put(autofill_values, key, value)}
    else
      {params, autofill_values}
    end
  end

  defp clear_previous_autofill(params, autofill_values) do
    Enum.reduce(autofill_values, params, fn {key, value}, params ->
      if Map.get(params, key) == value, do: Map.put(params, key, ""), else: params
    end)
  end

  defp track_manual_change(state, key, params) when is_binary(key) do
    case Map.fetch(state.autofill_values, key) do
      {:ok, autofill_value} ->
        if autofill_value == Map.get(params, key) do
          state
        else
          %{state | autofill_values: Map.delete(state.autofill_values, key)}
        end

      _other ->
        state
    end
  end

  defp track_manual_change(state, _key, _params), do: state

  defp media(params), do: params |> Map.get("media", "") |> String.trim()

  defp external_media_type?(%{slug: "external-media"}), do: true
  defp external_media_type?(_type), do: false

  defp external_media_metadata(
         %{provider: :youtube, kind: :playlist} = metadata,
         source_url
       ) do
    %{
      item_count: Map.get(metadata, :item_count),
      kind: :playlist,
      playlist_items: Map.get(metadata, :playlist_items, []),
      provider: :youtube,
      source_url: source_url,
      thumbnail_url: Map.get(metadata, :thumbnail_url)
    }
  end

  defp external_media_metadata(_metadata, _source_url), do: nil
end
