defmodule WikWeb.Components.Event.ExternalDetails do
  use WikWeb, :html

  alias WikWeb.Components.Event
  alias WikWeb.Components.Event.ExternalDescriptionScrubber

  attr :item, :map, required: true
  attr :user_tz, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-5" data-testid="external-event-detail">
      <div>
        <div class="flex justify-between gap-2 mb-4">
          <h2 class={[
            "truncate text-base font-medium leading-tight",
            "flex-grow",
            @item.status == :cancelled && "line-through decoration-base-content"
          ]}>
            {@item.title}
          </h2>

          <Event.event_status event={@item} />
        </div>

        <div class="grid grid-cols-[1fr_auto] gap-4">
          <div>
            <Event.schedule class="text-sm opacity-70" event={@item} user_tz={@user_tz} />
          </div>
        </div>
      </div>

      <div :if={present?(@item.location)} class="flex gap-2 items-start">
        <.icon name="hero-map-pin-mini" class="mt-0.5" />
        <div class="min-w-0">
          <div class="text-sm">{@item.location}</div>
        </div>
      </div>

      <div :if={present?(@item.description)}>
        <div class="text-xs uppercase tracking-wide opacity-50">
          Description
        </div>

        <div class={[
          "text-sm leading-6",
          "border border-base-300 rounded-md bg-base-content/5 px-4 py-2"
        ]}>
          <.description description={@item.description} />
        </div>
      </div>

      <div class="space-y-3">
        <dl :if={present?(@item.calendar_name)} class="space-y-1">
          <dt class="text-xs uppercase tracking-wide opacity-50">Calendar</dt>
          <dd class="text-xs opacity-70">{@item.calendar_name}</dd>
        </dl>

        <dl :if={present?(@item.event_url)} class="space-y-1">
          <dt class="text-xs uppercase tracking-wide opacity-50">Event URL</dt>
          <dd class="text-sm break-all">
            <.link
              class="link link-hover underline decoration-dashed underline-offset-2"
              href={@item.event_url}
              rel="noopener noreferrer"
              target="_blank"
            >
              {@item.event_url}
            </.link>
          </dd>
        </dl>
      </div>
    </div>
    """
  end

  attr :description, :string, required: true

  defp description(assigns) do
    assigns = assign(assigns, :description_content, description_content(assigns.description))

    ~H"""
    <%= case @description_content do %>
      <% {:text, description} -> %>
        <div class="whitespace-pre-wrap text-xs">{description}</div>
      <% {:html, description_html} -> %>
        <div class={[
          "whitespace-pre-wrap text-xs",
          "[&_a]:link",
          "[&_a]:link-hover",
          "[&_a]:underline",
          "[&_a]:decoration-dashed",
          "[&_a:hover]:decoration-solid",
          "[&_a]:underline-offset-2"
        ]}>
          <div class="">{raw(description_html)}</div>
        </div>
    <% end %>
    """
  end

  defp present?(value), do: value not in [nil, ""]

  defp description_content(description) do
    if html_description?(description) do
      {:html,
       description
       |> String.trim()
       |> ExternalDescriptionScrubber.sanitize()
       |> clean_link_urls()
       |> open_links_in_new_tab()}
    else
      {:text, description}
    end
  end

  defp html_description?(description) do
    Regex.match?(~r/<\/?[a-zA-Z][^>]*>/, description)
  end

  defp open_links_in_new_tab(html) do
    Regex.replace(~r/<a\b([^>]*)>/, html, fn _match, attributes ->
      ~s(<a#{attributes} target="_blank" rel="noopener noreferrer">)
    end)
  end

  defp clean_link_urls(html) do
    Regex.replace(~r/<a\b([^>]*)href="([^"]*)"([^>]*)>/, html, fn _match,
                                                                  before,
                                                                  href,
                                                                  trailing ->
      cleaned_href =
        href
        |> String.replace("&amp;", "&")
        |> maybe_unwrap_google_redirect_url()

      ~s(<a#{before}href="#{cleaned_href}"#{trailing}>)
    end)
  end

  defp maybe_unwrap_google_redirect_url(url) do
    uri = URI.parse(url)

    with "www.google.com" <- uri.host,
         "/url" <- uri.path,
         query when is_binary(query) <- uri.query,
         %{"q" => redirect_url} <- URI.decode_query(query),
         true <- safe_external_url?(redirect_url) do
      redirect_url
    else
      _ -> url
    end
  end

  defp safe_external_url?(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and is_binary(host) and host != "" ->
        true

      _ ->
        false
    end
  end
end
