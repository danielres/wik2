defmodule QblogWeb.Components.Block.Types.GoogleMaps do
  use QblogWeb, :html

  alias QblogWeb.Components.Block.Types.Embed

  attr :block, :map, required: true

  def render(assigns) do
    ~H"""
    <Embed.wrapper>
      <%= if @block.data["url"] do %>
        <iframe
          allowfullscreen
          class="aspect-video w-full"
          loading="lazy"
          referrerpolicy="no-referrer-when-downgrade"
          src={@block.data["url"]}
        >
        </iframe>
      <% else %>
        <div class="opacity-60">Empty Google Maps block</div>
      <% end %>
    </Embed.wrapper>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns), do: Embed.form_fields(assigns)
end
