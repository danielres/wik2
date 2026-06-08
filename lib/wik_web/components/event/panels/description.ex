defmodule WikWeb.Components.Event.Panels.Description do
  use WikWeb, :html

  alias WikWeb.Components.Event.ExternalDescriptionScrubber

  attr :description, :string, default: nil
  attr :format, :atom, default: :plain, values: [:plain, :external]

  def render(assigns) do
    ~H"""
    <WikWeb.Components.Event.Panel.render :if={@description not in [nil, ""]} title="Description">
      <div class={[
        "rounded-md bg-base-content/5 px-4 py-2 text-base-content/90",
        "text-xs leading-6"
      ]}>
        <%= if @format == :external do %>
          <.external_description description={@description} />
        <% else %>
          <div class="whitespace-pre-wrap">{@description}</div>
        <% end %>
      </div>
    </WikWeb.Components.Event.Panel.render>
    """
  end

  attr :description, :string, required: true

  defp external_description(assigns) do
    assigns = assign(assigns, :description_content, description_content(assigns.description))

    ~H"""
    <%= case @description_content do %>
      <% {:text, description_html} -> %>
        <div class="whitespace-pre-wrap text-xs">{raw(description_html)}</div>
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

  defp description_content(description) do
    if html_description?(description) do
      {:html,
       description
       |> String.trim()
       |> ExternalDescriptionScrubber.sanitize()
       |> clean_link_urls()
       |> open_links_in_new_tab()}
    else
      {:text, auto_link_plain_text(description)}
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
