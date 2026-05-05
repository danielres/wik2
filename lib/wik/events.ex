defmodule Wik.Events do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Wik.Events.Event
  alias Wik.Events.EventPublication

  admin do
    show? true
  end

  resources do
    resource Event
    resource EventPublication
  end

  def create_event(attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])
    opts = Keyword.put_new(opts, :return_notifications?, true)

    case Event.create(attrs, opts) do
      {:ok, event, notifications} ->
        Ash.Notifier.notify(notifications)
        Ash.load(event, load, scope: scope)

      {:ok, event} ->
        Ash.load(event, load, scope: scope)

      {:error, error} ->
        {:error, error}
    end
  end

  def relay_event_to_group(%Event{} = event, target_group, opts) do
    scope = Keyword.fetch!(opts, :scope)
    relay_note = Keyword.get(opts, :relay_note)
    relay_scope = %{scope | tenant: target_group}

    attrs =
      if is_nil(relay_note),
        do: %{event_id: event.id},
        else: %{event_id: event.id, relay_note: relay_note}

    EventPublication.relay_to_group(attrs, scope: relay_scope)
  end
end
