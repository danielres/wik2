defmodule WikWeb.Components.TextContent do
  use WikWeb, :html
  use HtmlSanitizeEx

  allow_tag_with_uri_attributes("a", ["href"], ["http", "https", "mailto"])
  allow_tag_with_these_attributes("a", ["title"])
  allow_tag_with_these_attributes("br", [])
  allow_tag_with_these_attributes("em", [])
  allow_tag_with_these_attributes("li", [])
  allow_tag_with_these_attributes("ol", [])
  allow_tag_with_these_attributes("p", [])
  allow_tag_with_these_attributes("strong", [])
  allow_tag_with_these_attributes("ul", [])

  attr :class, :any, default: nil
  attr :text, :string, required: true

  def render(assigns) do
    assigns = assign(assigns, :content, content(assigns.text))

    ~H"""
    <%= case @content do %>
      <% {:text, html} -> %>
        <div class={["whitespace-pre-wrap", @class]}>{raw(html)}</div>
      <% {:html, html} -> %>
        <div class={[
          "whitespace-pre-wrap",
          "[&_a]:link",
          "[&_a]:link-hover",
          "[&_a]:underline",
          "[&_a]:decoration-dashed",
          "[&_a:hover]:decoration-solid",
          "[&_a]:underline-offset-2",
          @class
        ]}>
          <div>{raw(html)}</div>
        </div>
    <% end %>
    """
  end

  defp content(text) do
    if html?(text) do
      {:html,
       text
       |> String.trim()
       |> sanitize()
       |> clean_link_urls()
       |> open_links_in_new_tab()}
    else
      {:text, auto_link_plain_text(text)}
    end
  end

  defp html?(text) do
    Regex.match?(~r/<\/?[a-zA-Z][^>]*>/, text)
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
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()

      ~s(<a#{before}href="#{cleaned_href}"#{trailing}>)
    end)
  end

  defp auto_link_plain_text(text) do
    Regex.split(~r/(https?:\/\/[^\s<]+)/, text, include_captures: true, trim: false)
    |> Enum.map_join(&plain_text_part_to_html/1)
  end

  defp plain_text_part_to_html(part) do
    if safe_external_url?(part) do
      href =
        part
        |> maybe_unwrap_google_redirect_url()
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()

      label =
        part
        |> Phoenix.HTML.html_escape()
        |> Phoenix.HTML.safe_to_string()

      ~s(<a class="link link-hover underline decoration-dashed underline-offset-2 hover:decoration-solid" href="#{href}" target="_blank" rel="noopener noreferrer">#{label}</a>)
    else
      part
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()
    end
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
