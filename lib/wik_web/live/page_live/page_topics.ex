defmodule WikWeb.PageLive.PageTopics do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2, assign: 3, to_form: 2]
  import Phoenix.LiveView, only: [connected?: 1, put_flash: 3]

  alias Wik.Tags
  alias Wik.Tags.Tag
  alias Wik.Tags.Tagging
  alias Wik.Tags.TopicSummaries

  def assign_defaults(socket) do
    assign(socket,
      page_topic_edit_tagging_id: nil,
      page_topic_form: nil,
      page_topic_options: [],
      page_topic_summaries: [],
      page_taggings: [],
      page_tagging_topic: nil
    )
  end

  def assign_topics(%{assigns: %{page: nil}} = socket) do
    assign(socket,
      page_topic_options: [],
      page_topic_summaries: [],
      page_taggings: []
    )
  end

  def assign_topics(%{assigns: %{page: page, current_scope: scope}} = socket) do
    if connected?(socket) do
      WikWeb.Endpoint.subscribe(Tag.space_pub_sub_topic(scope.tenant.id))
    end

    with {:ok, taggings} <- Tags.list_taggings(page, scope: scope),
         {:ok, tags} <- Tags.list_space_tags(scope) do
      assign(socket,
        page_topic_options: page_topic_options(tags, taggings, current_membership(socket)),
        page_topic_summaries: page_topic_summaries(taggings, current_membership(socket)),
        page_taggings: taggings
      )
    else
      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "page topics load failed")

        assign(socket,
          page_topic_options: [],
          page_topic_summaries: [],
          page_taggings: []
        )
    end
  end

  def close_form(socket) do
    assign(socket,
      page_topic_edit_tagging_id: nil,
      page_topic_form: nil
    )
  end

  def open_form(socket) do
    assign(socket,
      page_topic_edit_tagging_id: nil,
      page_topic_form: form()
    )
  end

  def edit_cancel(socket) do
    assign(socket, :page_topic_edit_tagging_id, nil)
  end

  def edit_start(socket, tagging_id) do
    current_tagging =
      Enum.find(socket.assigns.page_topic_summaries, fn summary ->
        summary.current_member_tagging && summary.current_member_tagging.id == tagging_id
      end)

    if current_tagging do
      assign(socket, :page_topic_edit_tagging_id, tagging_id)
    else
      socket
    end
  end

  def remove(socket, tag_id) do
    scope = socket.assigns.current_scope

    with %{} = membership <- current_membership(socket),
         %{} = page <- socket.assigns.page,
         {:ok, _tagging} <- Tags.remove_tagging(page, membership, tag_id, scope: scope) do
      assign_topics(socket)
    else
      {:error, :not_found} ->
        assign_topics(socket)

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "page topic remove failed")
        socket

      _other ->
        socket
    end
  end

  def refresh_if_watched(socket, topic) do
    if topic in watched_topics(socket) do
      assign_topics(socket)
    else
      socket
    end
  end

  def submit(socket, params) do
    scope = socket.assigns.current_scope

    with {:ok, tagging_params} <- parse_params(params),
         %{} = membership <- current_membership(socket),
         %{} = page <- socket.assigns.page,
         {:ok, _tagging} <-
           Tags.upsert_tagging(
             page,
             membership,
             tagging_params.tag_id,
             %{dimensions: %{"relevancy" => tagging_params.relevancy_level}},
             scope: scope
           ) do
      socket
      |> close_form()
      |> assign_topics()
    else
      {:error, message} when is_binary(message) ->
        assign_form_error(socket, params, message)

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "page topic submit failed")
        assign_form_error(socket, params, "Couldn't save that topic.")

      _other ->
        assign_form_error(socket, params, "Couldn't save that topic.")
    end
  end

  def sync_subscription(socket) do
    if connected?(socket) do
      current_topic =
        socket.assigns.page && Tagging.target_pub_sub_topic("page", socket.assigns.page.id)

      previous_topic = socket.assigns.page_tagging_topic

      cond do
        current_topic == previous_topic ->
          socket

        true ->
          if previous_topic, do: WikWeb.Endpoint.unsubscribe(previous_topic)
          if current_topic, do: WikWeb.Endpoint.subscribe(current_topic)

          assign(socket, :page_tagging_topic, current_topic)
      end
    else
      socket
    end
  end

  def validate(socket, params) do
    assign(socket, :page_topic_form, form(params))
  end

  defp assign_form_error(socket, params, message) do
    socket
    |> assign(:page_topic_form, form(params))
    |> put_flash(:error, message)
  end

  defp current_membership(socket) do
    socket.assigns.tenant_context && socket.assigns.tenant_context.current_membership
  end

  defp form(params \\ %{}) do
    params
    |> normalize_form()
    |> to_form(as: :page_topic)
  end

  defp normalize_form(params) do
    %{
      "relevancy_level" => Map.get(params, "relevancy_level", "5"),
      "tag_id" => Map.get(params, "tag_id", "")
    }
  end

  defp page_topic_options(tags, _taggings, nil), do: tags

  defp page_topic_options(tags, taggings, membership) do
    existing_tag_ids =
      taggings
      |> Enum.filter(&(&1.tagged_by_membership_id == membership.id))
      |> MapSet.new(& &1.tag_id)

    Enum.reject(tags, &MapSet.member?(existing_tag_ids, &1.id))
  end

  defp page_topic_summaries(taggings, current_membership) do
    TopicSummaries.build(taggings, current_membership)
  end

  defp parse_params(params) do
    with tag_id when is_binary(tag_id) and tag_id != "" <- Map.get(params, "tag_id"),
         {:ok, relevancy_level} <- parse_level(params, "relevancy_level") do
      {:ok, %{relevancy_level: relevancy_level, tag_id: tag_id}}
    else
      _ -> {:error, "Select a topic and enter a valid relevancy level."}
    end
  end

  defp parse_level(params, key) do
    params
    |> Map.get(key, "0")
    |> Integer.parse()
    |> case do
      {level, ""} when level in 1..10 -> {:ok, level}
      _other -> :error
    end
  end

  defp watched_topics(socket) do
    page_id = socket.assigns.page && socket.assigns.page.id

    [Tag.space_pub_sub_topic(socket.assigns.current_scope.tenant.id)] ++
      if(page_id,
        do: [Tagging.target_pub_sub_topic("page", page_id)],
        else: []
      )
  end
end
