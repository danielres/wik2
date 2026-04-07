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

  # TODO: rename to form_fields
  def form_fields(assigns) do
    case assigns.block.type do
      :text -> Components.Text.form_fields(assigns)
      :google_maps -> Components.GoogleMaps.form_fields(assigns)
    end
  end
end
