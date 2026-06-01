defmodule WikWeb.Components.Event.ExternalDescriptionScrubber do
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
end
