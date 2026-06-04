defmodule Wik.Events.Dimensions do
  @definitions %{
    "participation" => %{
      "interest" => %{
        color: "oklch(63% 0.13 358)",
        key: "interest",
        label: "Interest",
        max: 10
      }
    }
  }

  def get!(dimension_type, key) when is_binary(dimension_type) and is_binary(key) do
    @definitions
    |> Map.fetch!(dimension_type)
    |> Map.fetch!(key)
  end
end
