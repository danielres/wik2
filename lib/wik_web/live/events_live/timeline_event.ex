defmodule WikWeb.EventsLive.TimelineEvent do
  def schedule_event(%{source_external_event: %{id: _id} = external_event}), do: external_event
  def schedule_event(event), do: event

  def display_event(%{source_external_event: %{id: _id} = external_event} = local_event) do
    %{external_event | title: local_event.title || external_event.title}
  end

  def display_event(event), do: event
end
