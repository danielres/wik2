defmodule Wik.Events do
  use Ash.Domain,
    otp_app: :wik,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  alias Wik.Events.Event
  alias Wik.Events.EventPublication
  alias Wik.Repo

  admin do
    show? true
  end

  resources do
    resource Event do
      define :get_event_by_id, action: :read, get_by: [:id]
    end

    resource EventPublication
  end

  def create_event(attrs, opts) do
    scope = Keyword.fetch!(opts, :scope)
    load = Keyword.get(opts, :load, [])
    transaction_opts = Keyword.put(opts, :return_notifications?, true)

    case Repo.transaction(fn ->
           with {:ok, event, event_notifications} <- Event.create(attrs, transaction_opts),
                {:ok, _publication, publication_notifications} <-
                  EventPublication.publish_to_origin_group(
                    %{event_id: event.id},
                    transaction_opts
                  ) do
             {event, event_notifications ++ publication_notifications}
           else
             {:error, error} -> Repo.rollback(error)
           end
         end) do
      {:ok, {event, notifications}} ->
        Ash.Notifier.notify(notifications)
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
      %{event_id: event.id}
      |> maybe_put_relay_note(relay_note)

    EventPublication.relay_to_group(attrs, scope: relay_scope)
  end

  defp maybe_put_relay_note(attrs, nil), do: attrs
  defp maybe_put_relay_note(attrs, relay_note), do: Map.put(attrs, :relay_note, relay_note)
end
