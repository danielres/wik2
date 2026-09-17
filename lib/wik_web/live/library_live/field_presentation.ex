defmodule WikWeb.LibraryLive.FieldPresentation do
  def entry_icon(%{key: "organization"}), do: "hero-home-micro"
  def entry_icon(%{key: "role"}), do: "hero-academic-cap-micro"
  def entry_icon(%{key: "duration"}), do: "hero-clock-micro"
  def entry_icon(%{key: "creator"}), do: "hero-user-circle-micro"
  def entry_icon(%{type: :text}), do: nil
  def entry_icon(%{type: type}), do: schema_icon(type)

  def schema_icon(:boolean), do: "hero-check-circle-micro"
  def schema_icon(:date), do: "hero-calendar-days-micro"
  def schema_icon(:email), do: "hero-envelope-micro"
  def schema_icon(:location), do: "hero-map-pin-micro"
  def schema_icon(:media), do: "hero-play-circle-micro"
  def schema_icon(:number), do: "hero-hashtag-micro"
  def schema_icon(:phone), do: "hero-phone-micro"
  def schema_icon(:rich_text), do: "hero-document-text-micro"
  def schema_icon(:select), do: "hero-chevron-up-down-micro"
  def schema_icon(:title), do: "hero-key-micro"
  def schema_icon(:url), do: "hero-link-micro"
  def schema_icon(_type), do: "hero-bars-3-bottom-left-micro"
end
