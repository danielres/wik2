defmodule WikWeb.EventsLive.TimelineState do
  use WikWeb, :verified_routes

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]

  alias Utils.Log
  alias WikWeb.EventsLive.Params
  alias WikWeb.EventsLive.SubscriptionState
  alias WikWeb.EventsLive.TimelineLoader
  alias WikWeb.EventsLive.TimelinePresenter

  def empty(show_external? \\ false) do
    %{
      show_external?: show_external?,
      future_windows: 1,
      internal_publications: [],
      internal_items: [],
      external_items: [],
      load_more_path: nil,
      more_external_future?: false,
      items: [],
      grouped_items: []
    }
  end

  def refresh_page_data(socket) do
    scope = socket.assigns.current_scope
    timeline = socket.assigns.timeline

    with {:ok, loaded_data} <-
           TimelineLoader.load(scope,
             show_external?: timeline.show_external?,
             future_windows: timeline.future_windows
           ) do
      presented_timeline = TimelinePresenter.build(loaded_data, timeline.show_external?)

      socket
      |> put_loaded_timeline(presented_timeline)
      |> put_loaded_subscriptions(presented_timeline)
    else
      {:error, error} ->
        Log.scoped_error(scope, error, "refresh_page_data failed")

        socket
        |> assign(:timeline, %{
          socket.assigns.timeline
          | internal_publications: [],
            internal_items: [],
            external_items: [],
            load_more_path: nil,
            more_external_future?: false,
            items: [],
            grouped_items: []
        })
        |> assign(:subscriptions, SubscriptionState.empty())
        |> put_flash(:error, "Could not load events")
    end
  end

  def put_show_external(socket, show_external?) do
    socket
    |> assign(:timeline, %{socket.assigns.timeline | show_external?: show_external?})
    |> put_timeline_items()
  end

  def put_future_windows(socket, future_windows) do
    assign(socket, :timeline, %{socket.assigns.timeline | future_windows: future_windows})
  end

  defp put_loaded_timeline(socket, loaded_data) do
    socket
    |> assign(:timeline, %{
      socket.assigns.timeline
      | internal_publications: loaded_data.internal_publications,
        internal_items: loaded_data.internal_items,
        external_items: loaded_data.external_items,
        more_external_future?: loaded_data.more_external_future?
    })
    |> put_timeline_items()
  end

  defp put_loaded_subscriptions(socket, loaded_data) do
    subscriptions =
      socket.assigns.subscriptions
      |> SubscriptionState.put_loaded_data(loaded_data)

    assign(socket, :subscriptions, subscriptions)
  end

  defp put_timeline_items(socket) do
    timeline = socket.assigns.timeline

    items =
      TimelinePresenter.timeline_items(
        timeline.internal_items,
        timeline.external_items,
        timeline.show_external?
      )

    current_scope = socket.assigns.current_scope
    items = with_timeline_item_paths(items, current_scope, timeline)

    assign(socket, :timeline, %{
      timeline
      | items: items,
        load_more_path: load_more_path(current_scope, timeline),
        grouped_items: TimelinePresenter.grouped_timeline_items(items)
    })
  end

  defp with_timeline_item_paths(items, current_scope, timeline) do
    Enum.map(items, fn
      %{source_type: :internal, publication: publication} = item ->
        Map.put(
          item,
          :open_path,
          internal_event_path(
            current_scope,
            publication.event_id,
            timeline.show_external?,
            timeline.future_windows
          )
        )

      %{source_type: :external, event: event} = item ->
        Map.put(item, :open_path, external_event_path(current_scope, event.id))
    end)
  end

  defp load_more_path(current_scope, %{show_external?: true, future_windows: future_windows}) do
    events_path(current_scope, Params.load_more_query(true, future_windows))
  end

  defp load_more_path(_current_scope, _timeline), do: nil

  defp internal_event_path(current_scope, event_id, show_external?, future_windows) do
    events_path(current_scope, Params.event_query(event_id, show_external?, future_windows))
  end

  defp external_event_path(current_scope, event_id) do
    events_path(current_scope, Params.external_event_query(event_id))
  end

  def events_path(current_scope, ""), do: ~p"/#{current_scope.tenant.slug}/events"

  def events_path(current_scope, query) do
    ~p"/#{current_scope.tenant.slug}/events" <> "?" <> query
  end
end
