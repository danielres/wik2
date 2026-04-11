defmodule QblogWeb.Components.Block.Types.GoogleCalendar do
  use QblogWeb, :html

  attr :block, :map, required: true

  def render(assigns) do
    ~H"""
    <%= if @block.data["url"] do %>
      <iframe
        class={[
          "aspect-square @sm/block:aspect-video",
          "w-full rounded-lg border-0",
          "contrast-80",
          "dark:invert dark:hue-rotate-180",
        ]}
        src={@block.data["url"]}
      >
      </iframe>
    <% else %>
      <div class="opacity-60">Empty Google Calendar block</div>
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
