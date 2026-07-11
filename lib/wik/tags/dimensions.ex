defmodule Wik.Tags.Dimensions do
  @definitions %{
    "membership" => %{
      "interest" => %{
        color: "oklch(63% 0.13 358)",
        icon: "hero-heart-micro",
        key: "interest",
        label: "Interest",
        max: 10
      },
      "skill" => %{
        color: "oklch(65% 0.15 255)",
        icon: "hero-academic-cap-micro",
        key: "skill",
        label: "Experience",
        max: 10
      }
    },
    "page" => %{
      "relevancy" => %{
        color: "oklch(50% 0.06 145)",
        icon: "hero-sparkles-micro",
        key: "relevancy",
        label: "Relevancy",
        max: 10
      }
    }
  }

  def all_for(taggable_type) when is_binary(taggable_type) do
    @definitions
    |> Map.get(taggable_type, %{})
    |> Map.values()
  end

  def get!(taggable_type, key) when is_binary(taggable_type) and is_binary(key) do
    @definitions
    |> Map.fetch!(taggable_type)
    |> Map.fetch!(key)
  end
end
