defmodule WikWeb.LibraryLive.ExternalMedia.SoundCloud do
  @moduledoc false

  @endpoint "https://soundcloud.com/oembed"

  def resolve(url, opts) do
    http_get = Keyword.get(opts, :http_get, &Req.get/2)

    with {:ok, %Req.Response{status: 200, body: body}} <-
           http_get.(@endpoint,
             params: [format: "json", url: String.trim(url)],
             receive_timeout: 5_000
           ),
         {:ok, metadata} <- metadata(body) do
      {:ok, Map.put(metadata, :provider, :soundcloud)}
    else
      {:error, %Req.TransportError{reason: reason}} -> {:error, {:transport_error, reason}}
      {:error, reason} when is_atom(reason) -> {:error, reason}
      {:error, error} when is_exception(error) -> {:error, {:request_error, error.__struct__}}
      {:error, _error} -> {:error, :request_error}
      {:ok, %Req.Response{status: status}} -> {:error, {:http_error, status}}
    end
  end

  defp metadata(%{"title" => title} = body) when is_binary(title) do
    {:ok,
     %{
       creator: present_string(body["author_name"]),
       description: present_string(body["description"]),
       duration: nil,
       thumbnail_url: present_string(body["thumbnail_url"]),
       title: present_string(title)
     }}
  end

  defp metadata(_body), do: {:error, :invalid_response}

  defp present_string(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      value -> value
    end
  end

  defp present_string(_value), do: nil
end
