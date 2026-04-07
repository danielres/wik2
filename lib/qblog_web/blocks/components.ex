defmodule QblogWeb.Blocks.Components do
  use QblogWeb, :html

  alias QblogWeb.Blocks.Components

  attr :block, :map, required: true

  def view(assigns) do
    case assigns.block.type do
      :text -> Components.Text.view(assigns)
      :google_maps -> Components.GoogleMaps.view(assigns)
    end
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form(assigns) do
    case assigns.block.type do
      :text -> Components.Text.form(assigns)
      :google_maps -> Components.GoogleMaps.form(assigns)
    end
  end
end
