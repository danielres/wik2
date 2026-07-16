defmodule WikWeb.Auth.ReturnTo do
  @moduledoc false

  @regex_ascii_control_character ~r/[\x00-\x1F\x7F]/

  def validate(path) when is_binary(path) do
    uri = URI.parse(path)

    cond do
      not String.starts_with?(path, "/") -> "/"
      String.starts_with?(path, "//") -> "/"
      unsafe_path?(path) -> "/"
      uri.host != nil -> "/"
      uri.scheme != nil -> "/"
      true -> path
    end
  end

  def validate(_path), do: "/"

  defp unsafe_path?(path) do
    String.contains?(path, "\\") or Regex.match?(@regex_ascii_control_character, path)
  end
end
