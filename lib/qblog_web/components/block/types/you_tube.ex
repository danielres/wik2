defmodule QblogWeb.Components.Block.Types.YouTube do
  use QblogWeb, :html

  attr :block, :map, required: true

  def render(assigns) do
    ~H"""
    <%= if @block.data["url"] do %>
      <iframe
        allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
        allowfullscreen
        class="aspect-video w-full rounded border-0"
        referrerpolicy="strict-origin-when-cross-origin"
        src={@block.data["url"]}
      >
      </iframe>
    <% else %>
      <div class="opacity-60">Empty YouTube block</div>
    <% end %>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    ~H"""
    <.input
      field={@form[:url]}
      id={"edit-block-url-#{@block.id}"}
      label="url"
      phx-mounted={JS.focus()}
      type="text"
    />
    """
  end
end
