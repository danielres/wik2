defmodule WikWeb.EventsLive.Components.SubscriptionDetails do
  use WikWeb, :live_component

  alias Utils.Log
  alias Utils.Values
  alias Wik.Events.ExternalCalendar
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Tags
  alias Wik.Tags.Dimensions
  alias Wik.Tags.TopicSummaries
  alias WikWeb.Components.DimensionsList
  alias WikWeb.Components.RangeInput
  alias WikWeb.Components.Time
  alias WikWeb.EventsLive.Components.TopicMatching
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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <div :if={@subscription} class="space-y-2">
        <section class="space-y-2 bg-base-content/3 rounded p-4">
          <dl :if={@subscription.cached_at} class="flex gap-4 items-center">
            <dt class="font-bold text-sm">
              Last updated:
            </dt>
            <dd class="text-sm flex items-center gap-2">
              <Time.relative_and_precise
                datetime={@subscription.cached_at}
                direction="right"
                ago?
              />
              <div class="tooltip tooltip-accent tooltip-xs tooltip-right">
                <div class="tooltip-content text-xs">Refresh now</div>
                <button
                  class={["btn btn-circle btn-xs btn-accent btn-ghost"]}
                  data-testid={"events-subscription-refresh-#{@subscription.id}"}
                  phx-click="external_calendar_subscription_refresh"
                  phx-target={@myself}
                  phx-value-id={@subscription.id}
                  type="button"
                >
                  <.icon name="hero-arrow-path-micro" class="size-3" />
                </button>
              </div>
            </dd>
          </dl>
        </section>

        <section class="collapse collapse-plus bg-base-content/3 rounded">
          <input type="checkbox" />
          <div class="collapse-title font-bold text-sm">Info</div>
          <div class="collapse-content text-sm space-y-4">
            <dl :if={@metadata.timezone} class="flex gap-4 items-center">
              <dt class="text-xs uppercase opacity-70">
                Timezone:
              </dt>

              <dd class="text-xs">
                {@metadata.timezone}
              </dd>
            </dl>

            <dl :if={@metadata.name} class="space-y-1">
              <dt class="text-xs uppercase opacity-70">
                Original name:
              </dt>
              <dd class="text-xs leading-tight bg-base-300/20 p-2 rounded text-base-content/90">
                {@metadata.name}
              </dd>
            </dl>

            <dl :if={@metadata.description} class="space-y-1">
              <dt class="text-xs uppercase opacity-70">
                Original description:
              </dt>
              <dd class="text-xs bg-base-300/20 p-2 rounded text-base-content/90">
                <div class="whitespace-pre-wrap">{@metadata.description}</div>
              </dd>
            </dl>

            <dl class="space-y-1">
              <dt class="text-xs uppercase opacity-70">Subscription URL:</dt>
              <dd>
                <input
                  class="input input-sm w-full border !cursor-text text-base-content/80 rounded bg-base-300/20"
                  value={@subscription.ics_url}
                  disabled
                />
              </dd>
            </dl>
          </div>
        </section>

        <section
          class="space-y-2 bg-base-content/3 rounded p-4"
          data-testid="events-subscription-topics"
        >
          <% relevancy_dimension =
            Dimensions.get!("external_calendar_subscription", "relevancy") %>

          <div class="flex justify-between gap-2 items-baseline">
            <div>
              <div class="font-bold text-sm">Topics: always applied</div>
              <p class="text-xs text-base-content/55">
                These topics apply to every event from this calendar.
              </p>
            </div>

            <button
              :if={
                can_manage_subscription?(@subscription, @current_scope) and
                  @current_membership != nil and @subscription_topic_options != []
              }
              type="button"
              class="btn btn-circle btn-xs btn-accent btn-soft"
              data-testid="events-subscription-topic-add"
              phx-click="subscription_topic_add_start"
              phx-target={@myself}
            >
              <span class="sr-only">Add topic</span>
              <.icon name="hero-plus-mini" class="size-3" />
            </button>
          </div>

          <DimensionsList.render
            dimension={relevancy_dimension}
            item_id={& &1.tag.id}
            items={@subscription_topic_summaries}
            level={& &1.average_relevancy}
            list_testid="events-subscription-topic-list"
            navigate={&~p"/#{@current_scope.tenant.slug}/topics/#{&1.tag.slug}"}
            testid_prefix="events-subscription-topic"
          >
            <:title :let={summary}>
              <div class="truncate text-sm">{summary.tag.name}</div>
            </:title>

            <:action :let={summary}>
              <button
                :if={
                  can_manage_subscription?(@subscription, @current_scope) and
                    summary.current_member_tagging
                }
                type="button"
                class={[
                  "btn btn-xs btn-circle btn-ghost text-error",
                  "opacity-50 hover:opacity-100 transition-opacity"
                ]}
                data-testid={"events-subscription-topic-remove-#{summary.tag.id}"}
                phx-click="subscription_topic_remove"
                phx-target={@myself}
                phx-value-tag_id={summary.tag.id}
              >
                <span class="sr-only">Remove topic</span>
                <.icon name="hero-x-mark" class="size-3" />
              </button>
            </:action>
          </DimensionsList.render>

          <.form
            :if={@subscription_topic_form}
            for={@subscription_topic_form}
            id="events-subscription-topic-form"
            class="space-y-3 rounded-box border border-base-300 bg-base-100 p-3"
            data-testid="events-subscription-topic-form"
            phx-change="subscription_topic_validate"
            phx-submit="subscription_topic_submit"
            phx-target={@myself}
          >
            <.input
              field={@subscription_topic_form[:tag_id]}
              label="Topic"
              options={Enum.map(@subscription_topic_options, &{&1.name, &1.id})}
              prompt="Select a topic"
              type="select"
            />

            <RangeInput.render
              field={@subscription_topic_form[:relevancy_level]}
              dimension={relevancy_dimension}
              label={relevancy_dimension.label}
              max_level={relevancy_dimension.max}
            />

            <div class="flex justify-end gap-2">
              <button
                type="button"
                class="btn btn-ghost btn-sm"
                data-testid="events-subscription-topic-cancel"
                phx-click="subscription_topic_cancel"
                phx-target={@myself}
              >
                Cancel
              </button>

              <.button
                class="btn btn-accent btn-soft btn-sm"
                data-testid="events-subscription-topic-submit"
              >
                Save
              </.button>
            </div>
          </.form>
        </section>

        <section>
          <.live_component
            module={TopicMatching}
            id={"events-topic-matching-#{@subscription.id}"}
            can_manage?={can_manage_subscription?(@subscription, @current_scope)}
            current_scope={@current_scope}
            subscription={@subscription}
            view={@topic_matching_view}
          />
        </section>

        <section class="space-y-2 bg-base-content/3 rounded p-4">
          <.form
            :if={@name_form != nil}
            for={@name_form}
            id="events-subscription-name-form"
            data-testid="events-subscription-name-form"
            phx-submit="external_calendar_subscription_name_submit"
            phx-target={@myself}
          >
            <div class="space-y-3 [&_label]:text-sm [&_label]:opacity-100">
              <.input field={@name_form[:id]} type="hidden" />

              <.input
                field={@name_form[:custom_name]}
                label="Calendar: custom name (optional)"
                class="input input-sm w-full"
              />

              <div class="flex justify-between">
                <div class="flex gap-2">
                  <button
                    :if={Ash.can?({@subscription, :destroy}, @current_scope)}
                    class="btn btn-error btn-soft btn-sm"
                    data-testid={"events-subscription-remove-#{@subscription.id}"}
                    phx-click="external_calendar_subscription_remove"
                    phx-target={@myself}
                    phx-value-id={@subscription.id}
                    type="button"
                  >
                    <.icon name="hero-trash-mini" class="size-3" /> Remove subscription
                  </button>
                </div>

                <button
                  type="submit"
                  class="btn btn-accent btn-sm"
                  data-testid="events-subscription-name-submit"
                >
                  Save
                </button>
              </div>
            </div>
          </.form>
        </section>
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

  defp can_manage_subscription?(nil, _scope), do: false

  defp can_manage_subscription?(subscription, scope) do
    Ash.can?({subscription, :update_custom_name}, scope)
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
