defmodule Utils.Slugify do
  @spec generate(term()) :: String.t()
  def generate(title) when is_binary(title) do
    title
    |> String.trim()
    |> String.downcase()
    |> normalize_unicode()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
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
