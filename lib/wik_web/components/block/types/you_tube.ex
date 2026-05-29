defmodule WikWeb.Components.Block.Types.YouTube do
  use WikWeb, :html

  alias WikWeb.Components.Block.Types.Embed

  attr :block, :map, required: true

  def render(assigns) do
    ~H"""
    <Embed.wrapper block={@block}>
      <%= if @block.data["url"] do %>
        <div class={[
          "@lg/block:grid @lg/block:py-4",
          "justify-center items-center",
          "bg-base-200/50 rounded"
        ]}>
          <iframe
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
            allowfullscreen
            class={[
              "@lg/block:h-64",
              "aspect-video w-full",
              "rounded-lg",
              "border-0"
            ]}
            referrerpolicy="strict-origin-when-cross-origin"
            src={@block.data["url"]}
          >
          </iframe>
        </div>
      <% else %>
        <div class="opacity-60">Empty YouTube block</div>
      <% end %>
    </Embed.wrapper>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns), do: Embed.form_fields(assigns)
end
