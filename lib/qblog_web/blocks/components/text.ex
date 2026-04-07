defmodule QblogWeb.Blocks.Components.Text do
  use QblogWeb, :html

  attr :block, :map, required: true

  def view(assigns) do
    ~H"""
    <div class="whitespace-pre-line">
      {@block.data["text"] || "Empty block"}
    </div>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    ~H"""
    <.input
      field={@form[:text]}
      id={"edit-block-text-#{@block.id}"}
      phx-mounted={JS.focus()}
      type="textarea"
    />
    """
  end
end
