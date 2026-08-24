defmodule WikWeb.EventsLive.Components.TopicMatching do
  use WikWeb, :live_component

  alias Utils.Log
  alias Wik.Events.ExternalCalendar.TopicMatching, as: EventTopicMatching

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:editing?, fn -> false end)
     |> assign_new(:expanded_rule_id, fn -> nil end)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <section
      class={["rounded-box border border-primary/15 bg-primary/5 p-3", "space-y-3"]}
      data-testid="events-topic-matching"
    >
      <div class="flex items-start justify-between gap-3">
        <div class="min-w-0 space-y-1">
          <div class="flex flex-wrap items-center gap-2">
            <h3 class="font-bold text-sm">Topics: automatic matching</h3>
          </div>

          <p class="text-xs leading-relaxed text-base-content/65">
            Topic names and aliases are matched in event titles and descriptions.
          </p>
        </div>

        <button
          :if={@can_manage?}
          type="button"
          class={[
            "btn btn-xs rounded-full",
            @view.enabled? && "btn-primary",
            !@view.enabled? && "btn-ghost bg-base-200"
          ]}
          aria-checked={to_string(@view.enabled?)}
          data-testid="events-topic-matching-toggle"
          phx-click="topic_matching_subscription_toggle"
          phx-target={@myself}
          role="switch"
        >
          <.icon
            name={if(@view.enabled?, do: "hero-sparkles-micro", else: "hero-pause-micro")}
            class="size-3"
          />
          {if(@view.enabled?, do: "On", else: "Off")}
        </button>
      </div>

      <div
        :if={@view.topic_count == 0}
        class="rounded-box bg-base-100/70 px-3 py-4 text-center text-sm text-base-content/60"
        data-testid="events-topic-matching-empty-topics"
      >
        <p>Create topics for this space to start matching events automatically.</p>
        <.link
          navigate={~p"/#{@current_scope.tenant.slug}/topics"}
          class="link link-primary mt-2 inline-block text-xs"
        >
          Go to topics
        </.link>
      </div>

      <div :if={@view.topic_count > 0} class="space-y-3">
        <div class="grid grid-cols-3 gap-2" data-testid="events-topic-matching-stats">
          <.stat label="Topics" value={@view.topic_count} />
          <.stat label="Matched" value={@view.matched_topic_count} />
          <.stat label="Events" value={@view.matched_event_count} />
        </div>

        <div
          :if={@view.event_count == 0}
          class="rounded-box bg-base-100/70 px-3 py-3 text-xs text-base-content/60"
          data-testid="events-topic-matching-empty-events"
        >
          No imported events are currently loaded for this calendar.
        </div>

        <div
          :if={@view.enabled? and matching_rules(@view) != []}
          class="flex flex-wrap gap-1.5"
          data-testid="events-topic-matching-active-topics"
        >
          <span
            :for={rule <- matching_rules(@view)}
            class="badge badge-sm gap-1 border-primary/20 bg-primary/10 text-primary"
            data-testid={"events-topic-matching-active-#{rule.tag.id}"}
          >
            <.icon name="hero-sparkles-micro" class="size-3" />
            {rule.tag.name}
            <span class="opacity-60">{rule.count}</span>
          </span>
        </div>

        <div
          :if={@view.enabled? and @view.event_count > 0 and matching_rules(@view) == []}
          class="text-xs text-base-content/60"
          data-testid="events-topic-matching-zero-matches"
        >
          None of the current events match a topic yet.
        </div>

        <button
          type="button"
          class="btn btn-sm btn-ghost w-full justify-between bg-base-100/60"
          aria-expanded={to_string(@editing?)}
          data-testid="events-topic-matching-adjust"
          phx-click="topic_matching_editor_toggle"
          phx-target={@myself}
        >
          <span>{if(@can_manage?, do: "Adjust matching", else: "View matching rules")}</span>
          <.icon
            name={if(@editing?, do: "hero-chevron-up-micro", else: "hero-chevron-down-micro")}
            class="size-4 opacity-60"
          />
        </button>

        <div
          :if={@editing?}
          class="space-y-2"
          data-testid="events-topic-matching-rules"
        >
          <.rule
            :for={rule <- @view.rules}
            can_manage?={@can_manage?}
            expanded?={@expanded_rule_id == rule.tag.id}
            myself={@myself}
            rule={rule}
          />
        </div>
      </div>
    </section>
    """
  end

  attr :label, :string, required: true
  attr :value, :integer, required: true

  defp stat(assigns) do
    ~H"""
    <div class="rounded-box bg-base-100/70 px-2 py-2 text-center">
      <div class="text-base font-semibold tabular-nums">{@value}</div>
      <div class="text-[0.65rem] uppercase tracking-wide text-base-content/50">{@label}</div>
    </div>
    """
  end

  attr :can_manage?, :boolean, required: true
  attr :expanded?, :boolean, required: true
  attr :myself, :any, required: true
  attr :rule, :map, required: true

  defp rule(assigns) do
    assigns = assign(assigns, :alias_form, to_form(%{"value" => ""}, as: :topic_matching_alias))

    ~H"""
    <article
      class={[
        "rounded-box border bg-base-100/75 transition-colors",
        @expanded? && "border-primary/25",
        !@expanded? && "border-base-300"
      ]}
      data-testid={"events-topic-matching-rule-#{@rule.tag.id}"}
    >
      <div class="flex items-center gap-2 p-2">
        <button
          type="button"
          class="flex min-w-0 flex-1 items-center gap-2 text-left"
          aria-expanded={to_string(@expanded?)}
          data-testid={"events-topic-matching-rule-expand-#{@rule.tag.id}"}
          phx-click="topic_matching_rule_expand"
          phx-target={@myself}
          phx-value-tag_id={@rule.tag.id}
        >
          <.icon
            name={if(@expanded?, do: "hero-chevron-down-micro", else: "hero-chevron-right-micro")}
            class="size-3 shrink-0 opacity-50"
          />
          <span class="truncate text-sm font-medium">{@rule.tag.name}</span>
          <span class="badge badge-xs bg-base-200 tabular-nums">{@rule.count}</span>
        </button>

        <button
          :if={@can_manage?}
          type="button"
          class={[
            "btn btn-xs rounded-full",
            @rule.enabled? && "btn-primary btn-soft",
            !@rule.enabled? && "btn-ghost opacity-60"
          ]}
          aria-checked={to_string(@rule.enabled?)}
          data-testid={"events-topic-matching-rule-toggle-#{@rule.tag.id}"}
          phx-click="topic_matching_rule_toggle"
          phx-target={@myself}
          phx-value-tag_id={@rule.tag.id}
          role="switch"
        >
          {if(@rule.enabled?, do: "Enabled", else: "Disabled")}
        </button>
      </div>

      <div :if={@expanded?} class="border-t border-base-300/70 p-3 space-y-4">
        <div class="space-y-2">
          <div class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
            Match in
          </div>
          <div class="flex flex-wrap gap-2">
            <.field_button
              :for={{field, label} <- [{:title, "Title"}, {:description, "Description"}]}
              active?={Map.fetch!(@rule, field_enabled_key(field))}
              can_manage?={@can_manage?}
              disabled?={last_active_field?(@rule, field)}
              field={field}
              myself={@myself}
              rule={@rule}
              label={label}
            />
          </div>
        </div>

        <div class="space-y-2">
          <div class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
            Phrases
          </div>

          <div class="flex flex-wrap gap-1.5">
            <span class="badge badge-sm gap-1 bg-base-200">
              {@rule.tag.name}
              <span class="text-[0.6rem] uppercase opacity-45">Topic</span>
            </span>

            <span
              :for={alias_value <- @rule.aliases}
              class="badge badge-sm gap-1 border-primary/15 bg-primary/5"
              data-testid={"events-topic-matching-alias-#{@rule.tag.id}-#{alias_value}"}
            >
              {alias_value}
              <button
                :if={@can_manage?}
                type="button"
                class="opacity-50 transition-opacity hover:opacity-100"
                aria-label={"Remove #{alias_value}"}
                data-testid={"events-topic-matching-alias-remove-#{@rule.tag.id}-#{alias_value}"}
                phx-click="topic_matching_alias_remove"
                phx-target={@myself}
                phx-value-alias={alias_value}
                phx-value-tag_id={@rule.tag.id}
              >
                <.icon name="hero-x-mark" class="size-3" />
              </button>
            </span>
          </div>

          <.form
            :if={@can_manage?}
            for={@alias_form}
            id={"events-topic-matching-alias-form-#{@rule.tag.id}"}
            class="flex items-end gap-2"
            data-testid={"events-topic-matching-alias-form-#{@rule.tag.id}"}
            phx-submit="topic_matching_alias_add"
            phx-target={@myself}
            phx-value-tag_id={@rule.tag.id}
          >
            <.input
              field={@alias_form[:value]}
              label="Add an alias"
              placeholder="e.g. WCS"
              class="input input-sm w-full"
            />
            <button type="submit" class="btn btn-sm btn-primary btn-soft">
              <.icon name="hero-plus-micro" class="size-3" /> Add
            </button>
          </.form>
        </div>

        <div class="space-y-2">
          <div class="flex items-baseline justify-between gap-2">
            <div class="text-xs font-semibold uppercase tracking-wide text-base-content/50">
              Matching events
            </div>
            <span class="text-xs tabular-nums text-base-content/50">
              {@rule.count}
            </span>
          </div>

          <div
            :if={@rule.matches == []}
            class="rounded bg-base-200/50 px-3 py-2 text-xs text-base-content/55"
            data-testid={"events-topic-matching-preview-empty-#{@rule.tag.id}"}
          >
            No current events match this rule.
          </div>

          <div
            :if={@rule.matches != []}
            class="divide-y divide-base-300 rounded border border-base-300/70"
            data-testid={"events-topic-matching-preview-#{@rule.tag.id}"}
          >
            <div
              :for={match <- Enum.take(@rule.matches, 5)}
              class="flex items-start justify-between gap-3 px-3 py-2"
              data-testid={"events-topic-matching-preview-event-#{match.item.event.id}"}
            >
              <div class="min-w-0">
                <div class="truncate text-xs font-medium">{match.item.event.title}</div>
                <div class="text-[0.65rem] text-base-content/45">
                  {Calendar.strftime(match.item.event.starts_at, "%d %b %Y")}
                </div>
              </div>
              <span class="badge badge-xs shrink-0 bg-base-200">
                {field_labels(match.fields)}
              </span>
            </div>
          </div>

          <p :if={@rule.count > 5} class="text-right text-[0.65rem] text-base-content/45">
            Showing 5 of {@rule.count}
          </p>
        </div>
      </div>
    </article>
    """
  end

  attr :active?, :boolean, required: true
  attr :can_manage?, :boolean, required: true
  attr :disabled?, :boolean, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :myself, :any, required: true
  attr :rule, :map, required: true

  defp field_button(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "btn btn-xs rounded-full",
        @active? && "btn-primary btn-soft",
        !@active? && "btn-ghost bg-base-200",
        (!@can_manage? or @disabled?) && "pointer-events-none"
      ]}
      aria-pressed={to_string(@active?)}
      data-testid={"events-topic-matching-field-#{@field}-#{@rule.tag.id}"}
      disabled={!@can_manage? or @disabled?}
      phx-click="topic_matching_field_toggle"
      phx-target={@myself}
      phx-value-field={@field}
      phx-value-tag_id={@rule.tag.id}
    >
      <.icon
        name={if(@active?, do: "hero-check-micro", else: "hero-minus-micro")}
        class="size-3"
      />
      {@label}
    </button>
    """
  end

  @impl true
  def handle_event("topic_matching_editor_toggle", _params, socket) do
    {:noreply, update(socket, :editing?, &(!&1))}
  end

  def handle_event("topic_matching_rule_expand", %{"tag_id" => tag_id}, socket) do
    expanded_rule_id = if socket.assigns.expanded_rule_id == tag_id, do: nil, else: tag_id
    {:noreply, assign(socket, :expanded_rule_id, expanded_rule_id)}
  end

  def handle_event("topic_matching_subscription_toggle", _params, socket) do
    {:noreply, persist_update(socket, :toggle_subscription)}
  end

  def handle_event("topic_matching_rule_toggle", %{"tag_id" => tag_id}, socket) do
    {:noreply, persist_update(socket, {:toggle_rule, tag_id})}
  end

  def handle_event(
        "topic_matching_field_toggle",
        %{"field" => field, "tag_id" => tag_id},
        socket
      ) do
    field = if field == "title", do: :title?, else: :description?
    {:noreply, persist_update(socket, {:toggle_field, tag_id, field})}
  end

  def handle_event(
        "topic_matching_alias_add",
        %{"tag_id" => tag_id, "topic_matching_alias" => %{"value" => value}},
        socket
      ) do
    {:noreply, persist_update(socket, {:add_alias, tag_id, value})}
  end

  def handle_event(
        "topic_matching_alias_remove",
        %{"alias" => value, "tag_id" => tag_id},
        socket
      ) do
    {:noreply, persist_update(socket, {:remove_alias, tag_id, value})}
  end

  defp persist_update(%{assigns: %{can_manage?: true}} = socket, action) do
    subscription = socket.assigns.subscription
    scope = socket.assigns.current_scope

    case EventTopicMatching.update(subscription, action, scope: scope) do
      {:ok, _result} ->
        send(self(), {:events_live, {:subscription_refreshed, subscription.id}})
        socket

      {:error, error} ->
        Log.scoped_error(scope, error, "external calendar topic matching update failed")
        send(self(), {:events_live, {:flash, :error, "Couldn't save that matching rule."}})
        socket
    end
  end

  defp persist_update(socket, _action), do: socket

  defp matching_rules(view), do: Enum.filter(view.rules, &(&1.enabled? and &1.count > 0))

  defp field_enabled_key(:title), do: :title?
  defp field_enabled_key(:description), do: :description?

  defp last_active_field?(rule, :title), do: rule.title? and not rule.description?
  defp last_active_field?(rule, :description), do: rule.description? and not rule.title?

  defp field_labels(fields) do
    fields
    |> Enum.map(&Atom.to_string/1)
    |> Enum.join(" + ")
  end
end
