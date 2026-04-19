defmodule QblogWeb.Components.Block.Types.GoogleCalendar do
  use QblogWeb, :html

  alias QblogWeb.Components.Block.Types.Embed

  attr :block, :map, required: true

  def render(assigns) do
    ~H"""
    <Embed.wrapper>
      <%= if @block.data["url"] do %>
        <iframe
          class={[
            "aspect-square @sm/block:aspect-video",
            "w-full rounded border-0",
            "dark:contrast-80",
            "dark:invert dark:hue-rotate-180"
          ]}
          src={@block.data["url"]}
        >
        </iframe>
      <% else %>
        <div class="opacity-60">Empty Google Calendar block</div>
      <% end %>
    </Embed.wrapper>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns), do: Embed.form_fields(assigns)
end
