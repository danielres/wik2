defmodule WikWeb.Components.Event.Panels.Location do
  use WikWeb, :html

  attr :location, :string, default: nil
  attr :testid_prefix, :string, default: "event"

  def render(assigns) do
    ~H"""
    <div :if={@location not in [nil, ""]} class="flex gap-2 items-start">
      <.icon name="hero-map-pin-mini" class="mt-0.5" />
      <div class="min-w-0">
        <div class="text-sm">{@location}</div>
        <.link
          class="link link-hover text-xs opacity-70 flex items-center gap-0"
          data-testid={"#{@testid_prefix}-location-google-maps-link"}
          href={google_maps_search_url(@location)}
          rel="noopener noreferrer"
          target="_blank"
        >
          <span>Open in Google Maps</span>
          <.icon name="hero-arrow-top-right-on-square-micro" class="scale-80" />
        </.link>
      </div>
    </div>
    """
  end

  defp google_maps_search_url(location) do
    "https://www.google.com/maps/search/?" <>
      URI.encode_query(%{api: 1, query: location})
  end
end
