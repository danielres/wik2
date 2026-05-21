defmodule WikWeb.Components.CalendarFeed do
  use WikWeb, :html

  alias WikWeb.Components.UI
  alias Wik.Events.Feeds.Token

  attr :testid, :string, default: nil
  attr :scope, :map, required: true
  attr :id, :string, default: "aggregate-subscribe-button"

  def aggregate_subscribe_button(assigns) do
    current_user = assigns.scope.actor
    aggregate_feed_token = Token.issue_for_aggregate(current_user)
    url = url(~p"/calendar/#{aggregate_feed_token}")
    assigns = assigns |> assign(url: url)

    ~H"""
    <.subscribe_button
      id={@id}
      text="Paste the URL below in your personal calendar app to subscribe to all your events."
      url={@url}
    />
    """
  end

  attr :testid, :string, default: nil
  attr :scope, :map, required: true
  attr :id, :string, default: "group-subscribe-button"

  def group_subscribe_button(assigns) do
    current_user = assigns.scope.actor
    current_group = assigns.scope.tenant
    group_feed_token = Token.issue_for_group(current_user, current_group)
    url = url(~p"/calendar/#{group_feed_token}")
    assigns = assigns |> assign(url: url)

    ~H"""
    <.subscribe_button
      id={@id}
      text="Paste the URL below in your personal calendar app to subscribe to this group's events."
      url={@url}
    />
    """
  end

  attr :id, :string, default: "calendar-subscribe-button"
  attr :testid, :string, default: nil
  attr :text, :string, default: "Paste the URL below in your personal calendar app."
  attr :url, :string, required: true

  defp subscribe_button(assigns) do
    input_name = "#{assigns.id}-url"
    assigns = assigns |> assign(input_name: input_name)

    ~H"""
    <span class="flex items-center gap-1 text-sm opacity-70">
      <button
        class="btn btn-circle btn-xs"
        phx-click={UI.modal_open(@id)}
        data-testid={@testid}
      >
        <.icon name="hero-signal-micro" />
      </button>
    </span>

    <UI.modal id={@id}>
      <div class="space-y-1" data-testid={@testid}>
        <div class="text-xs text-balance">
          {@text}
        </div>

        <.input
          class="input w-full input-sm text-base-content/50 bg-base-300"
          id={@input_name}
          name={@input_name}
          readonly
          type="text"
          value={@url}
        />

        <div class="alert text-warning-content bg-warning/10 rounded-md">
          <.icon name="hero-exclamation-triangle-micro" class="opacity-50" />

          <div class="text-xs">
            This URL contains a secret token, is private to you and not meant to be shared with anyone else.
          </div>
        </div>
      </div>
    </UI.modal>
    """
  end
end
