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
      disabled_topic_ids: [],
      topic_options: [],
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
            disabled_topic_ids: [],
            topic_options: [],
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

  def toggle_topic_filter(socket, topic_id) when is_binary(topic_id) do
    timeline = socket.assigns.timeline
    topic_ids = Enum.map(timeline.topic_options, & &1.tag.id)
    enabled_topic_ids = topic_ids -- timeline.disabled_topic_ids

    disabled_topic_ids =
      cond do
        Enum.sort(enabled_topic_ids) == Enum.sort(topic_ids) ->
          topic_ids -- [topic_id]

        enabled_topic_ids == [topic_id] ->
          []

        topic_id in timeline.disabled_topic_ids ->
          Enum.reject(timeline.disabled_topic_ids, &(&1 == topic_id))

        true ->
          [topic_id | timeline.disabled_topic_ids]
      end

    socket
    |> assign(:timeline, %{timeline | disabled_topic_ids: disabled_topic_ids})
    |> put_timeline_items()
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

    unfiltered_items =
      TimelinePresenter.timeline_items(
        timeline.internal_items,
        timeline.external_items,
        timeline.show_external?
      )

    current_scope = socket.assigns.current_scope
    topic_options = topic_options(unfiltered_items)
    disabled_topic_ids = valid_disabled_topic_ids(timeline.disabled_topic_ids, topic_options)
    items = filter_items_by_topics(unfiltered_items, disabled_topic_ids)
    items = with_timeline_item_paths(items, current_scope, timeline)

    assign(socket, :timeline, %{
      timeline
      | items: items,
        disabled_topic_ids: disabled_topic_ids,
        topic_options: topic_options,
        load_more_path: load_more_path(current_scope, timeline),
        grouped_items: TimelinePresenter.grouped_timeline_items(items)
    })
  end

  defp topic_options(items) do
    items
    |> Enum.flat_map(&Map.get(&1, :topic_summaries, []))
    |> Enum.reject(&(is_nil(&1.tag) or is_nil(&1.tag.id)))
    |> Enum.group_by(& &1.tag.id)
    |> Enum.map(fn {_tag_id, summaries} ->
      summary = List.first(summaries)

      %{
        count: length(summaries),
        tag: summary.tag
      }
    end)
    |> Enum.sort_by(fn %{tag: tag} -> String.downcase(tag.name || "") end)
  end

  defp valid_disabled_topic_ids(disabled_topic_ids, topic_options) do
    option_ids = MapSet.new(topic_options, & &1.tag.id)
    Enum.filter(disabled_topic_ids, &MapSet.member?(option_ids, &1))
  end

  defp filter_items_by_topics(items, []), do: items

  defp filter_items_by_topics(items, disabled_topic_ids) do
    disabled_topic_ids = MapSet.new(disabled_topic_ids)

    Enum.filter(items, fn item ->
      item_topics = Map.get(item, :topic_summaries, [])

      item_topics == [] or
        Enum.any?(item_topics, &(not MapSet.member?(disabled_topic_ids, &1.tag.id)))
    end)
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
