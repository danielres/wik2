defmodule Utils.Values do
  def blank_to_nil(value) when value in [nil, ""], do: nil
  def blank_to_nil(value), do: value
end
