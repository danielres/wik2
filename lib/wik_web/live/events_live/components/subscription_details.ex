defmodule WikWeb.EventsLive.Components.SubscriptionDetails do
  use WikWeb, :live_component

  alias Utils.Log
  alias Utils.Values
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Tags
  alias Wik.Tags.TopicSummaries
  alias WikWeb.EventsLive.Components.SubscriptionDetails.Sections
  alias WikWeb.EventsLive.SubscriptionState

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:current_membership, fn -> nil end)
      |> assign_new(:subscription_topic_form, fn -> nil end)
      |> assign(:name_form, SubscriptionState.name_form(assigns.subscription))
      |> assign_subscription_topics()

    {:ok, socket}
  end

  attr :class, :string, default: ""
  attr :padding_class, :string, default: "p-4"
  attr :rest, :global
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <section
      class={[
        "bg-base-content/3 rounded",
        @class,
        @padding_class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </section>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={@subscription} class="space-y-2">
        <.section>
          <Sections.last_updated myself={@myself} subscription={@subscription} />
        </.section>

        <.section class="collapse collapse-plus" padding_class="">
          <Sections.info metadata={@metadata} subscription={@subscription} />
        </.section>

        <.section data-testid="events-subscription-topics">
          <Sections.topics_always_applied
            current_membership={@current_membership}
            current_scope={@current_scope}
            myself={@myself}
            subscription={@subscription}
            subscription_topic_form={@subscription_topic_form}
            subscription_topic_options={@subscription_topic_options}
            subscription_topic_summaries={@subscription_topic_summaries}
          />
        </.section>

        <.section data-testid="events-topic-matching">
          <Sections.topics_automatic_matching
            current_scope={@current_scope}
            subscription={@subscription}
            topic_matching_view={@topic_matching_view}
          />
        </.section>

        <.section>
          <Sections.form_custom_name
            current_scope={@current_scope}
            myself={@myself}
            name_form={@name_form}
            subscription={@subscription}
          />
        </.section>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("external_calendar_subscription_remove", %{"id" => id}, socket) do
    case ExternalCalendarSubscription.destroy(socket.assigns.subscription,
           scope: socket.assigns.current_scope
         ) do
      :ok ->
        removed(socket, id)

      {:ok, _subscription} ->
        removed(socket, id)

      {:error, error} ->
        flash_error(socket, error)
    end
  end

  def handle_event("external_calendar_subscription_refresh", %{"id" => id}, socket) do
    case ExternalCalendar.sync_subscription(socket.assigns.subscription) do
      {:ok, _subscription} ->
        send(self(), {:events_live, {:subscription_refreshed, id}})
        {:noreply, socket}

      {:error, error} ->
        Log.scoped_error(
          socket.assigns.current_scope,
          error,
          "external_calendar_subscription_refresh failed"
        )

        flash_error(socket, error)
    end
  end

  def handle_event(
        "external_calendar_subscription_name_submit",
        %{"subscription_name" => %{"id" => subscription_id, "custom_name" => custom_name}},
        socket
      ) do
    with {:ok, subscription} <-
           Ash.get(ExternalCalendarSubscription, subscription_id,
             scope: socket.assigns.current_scope
           ),
         {:ok, _updated_subscription} <-
           ExternalCalendarSubscription.update_custom_name(
             subscription,
             %{custom_name: Values.blank_to_nil(custom_name)},
             scope: socket.assigns.current_scope
           ) do
      send(self(), {:events_live, {:subscription_updated, subscription_id}})
      {:noreply, socket}
    else
      {:error, error} ->
        Log.scoped_error(
          socket.assigns.current_scope,
          error,
          "external_calendar_subscription_name_submit failed"
        )

        flash_error(socket, error)
    end
  end

  def handle_event("subscription_topic_add_start", _params, socket) do
    {:noreply, open_subscription_topic_form(socket)}
  end

  def handle_event("subscription_topic_cancel", _params, socket) do
    {:noreply, close_subscription_topic_form(socket)}
  end

  def handle_event("subscription_topic_validate", %{"subscription_topic" => params}, socket) do
    {:noreply, assign(socket, :subscription_topic_form, subscription_topic_form(params))}
  end

  def handle_event("subscription_topic_submit", %{"subscription_topic" => params}, socket) do
    scope = socket.assigns.current_scope

    socket =
      with {:ok, tagging_params} <- parse_subscription_topic_params(params),
           %{} = membership <- socket.assigns.current_membership,
           %{} = subscription <- socket.assigns.subscription,
           {:ok, _tagging} <-
             Tags.upsert_tagging(
               subscription,
               membership,
               tagging_params.tag_id,
               %{dimensions: %{"relevancy" => tagging_params.relevancy_level}},
               scope: scope
             ) do
        send(self(), {:events_live, {:subscription_refreshed, subscription.id}})

        socket
        |> close_subscription_topic_form()
        |> assign_subscription_topics()
      else
        {:error, message} when is_binary(message) ->
          assign_subscription_topic_form_error(socket, params, message)

        {:error, error} ->
          Log.scoped_error(scope, error, "subscription topic submit failed")
          assign_subscription_topic_form_error(socket, params, "Couldn't save that topic.")

        _other ->
          assign_subscription_topic_form_error(socket, params, "Couldn't save that topic.")
      end

    {:noreply, socket}
  end

  def handle_event("subscription_topic_remove", %{"tag_id" => tag_id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      with %{} = membership <- socket.assigns.current_membership,
           %{} = subscription <- socket.assigns.subscription,
           {:ok, _tagging} <- Tags.remove_tagging(subscription, membership, tag_id, scope: scope) do
        send(self(), {:events_live, {:subscription_refreshed, subscription.id}})
        assign_subscription_topics(socket)
      else
        {:error, :not_found} ->
          assign_subscription_topics(socket)

        {:error, error} ->
          Log.scoped_error(scope, error, "subscription topic remove failed")
          socket

        _other ->
          socket
      end

    {:noreply, socket}
  end

  defp assign_subscription_topics(%{assigns: %{subscription: nil}} = socket) do
    assign(socket,
      subscription_topic_form: nil,
      subscription_topic_options: [],
      subscription_topic_summaries: [],
      subscription_taggings: []
    )
  end

  defp assign_subscription_topics(
         %{assigns: %{subscription: subscription, current_scope: scope}} = socket
       ) do
    with {:ok, taggings} <- Tags.list_taggings(subscription, scope: scope),
         {:ok, tags} <- Tags.list_space_tags(scope) do
      assign(socket,
        subscription_topic_options:
          subscription_topic_options(tags, taggings, socket.assigns.current_membership),
        subscription_topic_summaries:
          subscription_topic_summaries(taggings, socket.assigns.current_membership),
        subscription_taggings: taggings
      )
    else
      {:error, error} ->
        Log.scoped_error(scope, error, "subscription topics load failed")

        assign(socket,
          subscription_topic_options: [],
          subscription_topic_summaries: [],
          subscription_taggings: []
        )
    end
  end

  defp subscription_topic_options(tags, _taggings, nil), do: tags

  defp subscription_topic_options(tags, taggings, membership) do
    existing_tag_ids =
      taggings
      |> Enum.filter(&(&1.tagged_by_membership_id == membership.id))
      |> MapSet.new(& &1.tag_id)

    Enum.reject(tags, &MapSet.member?(existing_tag_ids, &1.id))
  end

  defp subscription_topic_summaries(taggings, current_membership) do
    TopicSummaries.build(taggings, current_membership)
  end

  defp open_subscription_topic_form(socket) do
    assign(socket, :subscription_topic_form, subscription_topic_form())
  end

  defp close_subscription_topic_form(socket) do
    assign(socket, :subscription_topic_form, nil)
  end

  defp subscription_topic_form(params \\ %{}) do
    params
    |> normalize_subscription_topic_form()
    |> to_form(as: :subscription_topic)
  end

  defp normalize_subscription_topic_form(params) do
    %{
      "relevancy_level" => Map.get(params, "relevancy_level", "5"),
      "tag_id" => Map.get(params, "tag_id", "")
    }
  end

  defp parse_subscription_topic_params(params) do
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

  defp assign_subscription_topic_form_error(socket, params, message) do
    socket
    |> assign(:subscription_topic_form, subscription_topic_form(params))
    |> put_flash(:error, message)
  end

  defp removed(socket, id) do
    send(self(), {:events_live, {:subscription_removed, id}})
    {:noreply, socket}
  end

  defp flash_error(socket, error) do
    send(self(), {:events_live, {:flash, :error, SubscriptionState.error_message(error)}})
    {:noreply, socket}
  end
end
