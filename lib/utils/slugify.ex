defmodule Utils.Slugify do
  @match_regex ~r/^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$/
  @js_slugify_pattern "[^a-z0-9]+"
  @slugify_pattern Regex.compile!(@js_slugify_pattern, "u")

  @spec js_slugify_pattern() :: String.t()
  def js_slugify_pattern, do: @js_slugify_pattern

  @spec match_regex() :: Regex.t()
  def match_regex, do: @match_regex

  @spec generate(term()) :: String.t()
  def generate(title) when is_binary(title) do
    title
    |> String.trim()
    |> String.downcase()
    |> normalize_unicode()
    |> String.replace(@slugify_pattern, "-")
    |> String.trim("-")
  end

  def generate(_), do: ""

  @spec normalize_unicode(String.t()) :: String.t()
  defp normalize_unicode(string) do
    string
    |> :unicode.characters_to_nfd_binary()
    |> String.replace(~r/\p{M}/u, "")
  end
end
