defmodule WikWeb.EventsLive.TimelineEvent do
  def resolve(%{source_external_event: %{id: _id} = external_event} = local_event) do
    %{external_event | title: local_event.title || external_event.title}
  end

  def resolve(event), do: event
end
