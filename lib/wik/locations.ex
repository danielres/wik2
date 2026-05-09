defmodule Wik.Locations do
  @limit 5
  @lang "en"

  def enabled? do
    api_url() not in [nil, ""]
  end

  def search(query) do
    search(query, &Req.get/2)
  end

  def search(query, http_get) when is_binary(query) and is_function(http_get, 2) do
    query = String.trim(query)

    if query == "" or not enabled?() do
      {:ok, []}
    else
      api_url()
      |> http_get.(params: [q: query, limit: @limit, lang: @lang])
      |> search_from_response()
    end
  end

  defp api_url do
    Application.get_env(:wik, __MODULE__, [])
    |> Keyword.get(:api_url)
  end

  defp search_from_response({:ok, %Req.Response{status: 200, body: %{"features" => features}}})
       when is_list(features) do
    {:ok,
     features
     |> Enum.map(&feature_to_option/1)
     |> Enum.reject(&is_nil/1)
     |> Enum.uniq_by(& &1.value)}
  end

  defp search_from_response({:ok, %Req.Response{status: status, body: body}}) do
    {:error, {:http_error, status, body}}
  end

  defp search_from_response({:error, error}), do: {:error, error}

  defp feature_to_option(%{"properties" => properties}) when is_map(properties) do
    case format_label(properties) do
      nil -> nil
      label -> %{label: label, value: label}
    end
  end

  defp feature_to_option(_feature), do: nil

  defp format_label(properties) do
    properties
    |> label_parts()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(", ")
    |> case do
      "" -> nil
      label -> label
    end
  end

  defp label_parts(properties) do
    [
      properties["name"],
      street_line(properties),
      properties["city"] || properties["state"] || properties["county"],
      properties["country"]
    ]
  end

  defp street_line(properties) do
    [properties["street"], properties["housenumber"]]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join(" ")
    |> case do
      "" -> nil
      line -> line
    end
  end
end
