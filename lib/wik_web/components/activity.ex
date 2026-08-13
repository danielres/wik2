defmodule WikWeb.Components.Activity do
  use WikWeb, :html

  alias Wik.Accounts.Membership
  alias WikWeb.Components

  attr :active_category, :atom, required: true
  attr :category_paths, :map, required: true

  def category_nav(assigns) do
    assigns = assign(assigns, :categories, [:all | Wik.Activity.categories()])

    ~H"""
    <nav
      aria-label="Filter updates by category"
      class="flex flex-wrap gap-1 sm:ml-3"
      id="activity-category-filter"
    >
      <.link
        :for={category <- @categories}
        aria-current={if(@active_category == category, do: "page")}
        class={[
          "flex items-center gap-1",
          "relative top-1",
          "bg-base-200",
          "px-3 sm:px-4 py-2",
          "font-bold text-sm",
          "transition",
          "rounded-t-box rounded-b-none",
          @active_category != category && "opacity-30 hover:opacity-70 btn-ghost"
        ]}
        data-testid={"activity-category-#{category}"}
        id={"activity-category-#{category}"}
        patch={Map.fetch!(@category_paths, category)}
      >
        <div class="opacity-60 inline-flex">
          <.icon :if={category == :all} name="hero-eye-micro" />
          <.icon :if={category == :wiki} name="hero-book-open-micro" />
          <.icon :if={category == :topics} name="hero-tag-micro" />
          <.icon :if={category == :events} name="hero-calendar-micro" />
          <.icon :if={category == :members} name="hero-user-micro" />
          <.icon :if={category == :other} name="hero-ellipsis-horizontal-micro" />
        </div>
        <span class={@active_category != category && "max-sm:sr-only"}>
          {category_label(category)}
        </span>
      </.link>
    </nav>
    """
  end

  attr :empty_message, :string, default: "No updates in this category yet."
  attr :id, :string, required: true
  attr :page_size, :any, required: true
  attr :query, :any, required: true
  attr :scope, :any, required: true
  attr :search, :any, default: nil
  attr :show_pagination, :boolean, default: true
  attr :show_sort, :boolean, default: nil
  attr :url_state, :any, default: false
  attr :user_tz, :string, required: true
  attr :wrapper_id, :string, required: true

  def collection(assigns) do
    ~H"""
    <div id={@wrapper_id}>
      <Cinder.collection
        class={[
          "[&_thead]:hidden",
          "[&>*>*]:pt-2",
          "[&>*>*]:pb-4"
        ]}
        empty_message={@empty_message}
        id={@id}
        page_size={@page_size}
        query={@query}
        query_opts={[
          load: [
            :event_starts_at,
            actor_membership: [:avatar_url, :space, user: [:external_identities]]
          ]
        ]}
        scope={@scope}
        search={@search}
        show_filters={false}
        show_pagination={@show_pagination}
        show_sort={@show_sort}
        sort_mode="exclusive"
        theme={WikWeb.Cinder.Themes.Dense}
        url_state={@url_state}
      >
        <:col :let={entry} field="actor_label" label="">
          <.actor entry={entry} />
        </:col>

        <:col :let={entry} field="subject_label" label="">
          <div data-testid={"activity-entry-#{entry.id}"}>
            <.summary entry={entry} />
            <.note entry={entry} />
          </div>
        </:col>

        <:col :let={entry} field="occurred_at" label="" class="w-0">
          <Components.Time.relative_and_precise
            ago?
            class="text-xs"
            datetime={entry.occurred_at}
            user_tz={@user_tz}
          />
        </:col>
      </Cinder.collection>
    </div>
    """
  end

  def param_to_category(nil), do: :all

  def param_to_category(category) do
    Enum.find(Wik.Activity.categories(), :all, &(Atom.to_string(&1) == category))
  end

  attr :entry, :map, required: true
  attr :user_tz, :string, default: "Etc/UTC"

  def row(assigns) do
    ~H"""
    <div
      class={[
        "flex items-start gap-3 rounded p-3",
        "bg-base-200/70"
      ]}
      data-testid={"activity-entry-#{@entry.id}"}
    >
      <.actor entry={@entry} />

      <div class="min-w-0 flex-1">
        <.summary entry={@entry} />
        <.note entry={@entry} />
      </div>

      <div class="flex shrink-0 items-center gap-2 text-xs">
        <span :if={@entry.occurrence_count > 1} class="badge badge-ghost badge-xs">
          ×{@entry.occurrence_count}
        </span>
        <Components.Time.relative_and_precise
          ago?
          datetime={@entry.occurred_at}
          user_tz={@user_tz}
        />
      </div>
    </div>
    """
  end

  attr :entry, :map, required: true

  def actor(assigns) do
    ~H"""
    <Components.User.identity
      :if={match?(%Membership{}, @entry.actor_membership)}
      avatar_size="xs"
      class="max-w-36 text-xs"
      link?
      membership={@entry.actor_membership}
    />

    <span
      :if={!match?(%Membership{}, @entry.actor_membership)}
      class="flex items-center gap-1 text-xs text-base-content/65"
    >
      <span class="grid size-4 place-items-center rounded-full bg-base-300">
        <.icon name="hero-user-micro" class="size-3" />
      </span>
      {@entry.actor_label || "Someone"}
    </span>
    """
  end

  attr :entry, :map, required: true

  def summary(assigns) do
    assigns =
      assigns
      |> assign(:prefix, summary_prefix(assigns.entry))
      |> assign(:suffix_highlight, summary_suffix_highlight(assigns.entry))
      |> assign(:suffix, summary_suffix(assigns.entry))
      |> assign(:timing, event_timing(assigns.entry))

    ~H"""
    <p class="text-sm leading-snug">
      <span class="opacity-90">{@prefix}</span>
      <.link
        :if={@entry.subject_path}
        navigate={@entry.subject_path}
        class="font-bold hover:underline text-primary"
      >
        {@entry.subject_label}
      </.link>
      <span :if={!@entry.subject_path} class="font-bold">{@entry.subject_label}</span>
      <span class="opacity-90">{@suffix}</span>
      <span :if={@suffix_highlight} class="font-bold">
        {@suffix_highlight}
      </span>
      <span :if={@timing} class="text-base-content/60">{" · " <> @timing}</span>
    </p>
    """
  end

  attr :entry, :map, required: true

  def note(assigns) do
    assigns = assign(assigns, :note, metadata_value(assigns.entry, :note))

    ~H"""
    <p :if={@note not in [nil, ""]} class="mt-1 line-clamp-2 text-xs text-base-content/60">
      {@note}
    </p>
    """
  end

  defp summary_prefix(%{kind: :event_cancelled}), do: "cancelled "
  defp summary_prefix(%{kind: :event_created}), do: "created event "

  defp summary_prefix(%{kind: :event_participation_changed} = entry) do
    case metadata_value(entry, :interest_band) do
      "considering" -> "is considering "
      :considering -> "is considering "
      "likely" -> "is likely to join "
      :likely -> "is likely to join "
      "planning" -> "plans to join "
      :planning -> "plans to join "
      _other -> "updated interest in "
    end
  end

  defp summary_prefix(%{kind: :event_participation_removed}),
    do: "is no longer interested in "

  defp summary_prefix(%{kind: :event_relayed}), do: "shared event "
  defp summary_prefix(%{kind: :event_updated}), do: "updated event "
  defp summary_prefix(%{kind: :member_joined}), do: "joined the space: "
  defp summary_prefix(%{kind: :member_left}), do: "left the space: "
  defp summary_prefix(%{kind: :member_profile_updated}), do: "updated member profile "
  defp summary_prefix(%{kind: :member_role_changed}), do: "changed the role for "
  defp summary_prefix(%{kind: :member_tag_added}), do: "added a topic to "
  defp summary_prefix(%{kind: :member_tag_removed}), do: "removed a topic from "
  defp summary_prefix(%{kind: :member_tag_updated}), do: "updated a topic on "
  defp summary_prefix(%{kind: :page_created}), do: "created page "
  defp summary_prefix(%{kind: :page_deleted}), do: "deleted page "
  defp summary_prefix(%{kind: :page_updated}), do: "updated page "
  defp summary_prefix(%{kind: :space_created}), do: "created space "
  defp summary_prefix(%{kind: :space_updated}), do: "updated space "
  defp summary_prefix(%{kind: :topic_created}), do: "created topic "
  defp summary_prefix(%{kind: :topic_deleted}), do: "deleted topic "
  defp summary_prefix(%{kind: :topic_updated}), do: "updated topic "

  defp summary_suffix(%{kind: :member_role_changed} = entry) do
    case metadata_value(entry, :role) do
      nil -> ""
      _role -> " to "
    end
  end

  defp summary_suffix(%{kind: kind} = entry)
       when kind in [:member_tag_added, :member_tag_removed, :member_tag_updated] do
    case metadata_value(entry, :tag_label) do
      nil -> ""
      label -> " · #{label}"
    end
  end

  defp summary_suffix(%{kind: :page_updated} = entry) do
    case metadata_value(entry, :targets) do
      targets when is_list(targets) and length(targets) > 1 ->
        " and #{length(targets) - 1} other #{if(length(targets) == 2, do: "page", else: "pages")}"

      _targets ->
        ""
    end
  end

  defp summary_suffix(_entry), do: ""

  defp summary_suffix_highlight(%{kind: :member_role_changed} = entry) do
    case metadata_value(entry, :role) do
      nil -> nil
      role -> role |> to_string() |> String.capitalize()
    end
  end

  defp summary_suffix_highlight(_entry), do: nil

  defp event_timing(%{subject_type: :event, event_starts_at: %DateTime{} = starts_at}) do
    starts_at
    |> DateTime.diff(DateTime.utc_now(), :second)
    |> future_time()
  end

  defp event_timing(_entry), do: nil

  defp future_time(seconds) when seconds <= 0, do: nil
  defp future_time(seconds) when seconds < 60, do: "in less than a minute"
  defp future_time(seconds) when seconds < 3_600, do: future_time(seconds, 60, "minute")
  defp future_time(seconds) when seconds < 86_400, do: future_time(seconds, 3_600, "hour")
  defp future_time(seconds), do: future_time(seconds, 86_400, "day")

  defp future_time(seconds, unit_seconds, unit) do
    count = div(seconds + unit_seconds - 1, unit_seconds)
    "in #{count} #{unit}#{if(count == 1, do: "", else: "s")}"
  end

  defp metadata_value(%{metadata: metadata}, key) do
    Map.get(metadata, key) || Map.get(metadata, Atom.to_string(key))
  end

  defp category_label(:all), do: "All"
  defp category_label(:events), do: "Events"
  defp category_label(:members), do: "Members"
  defp category_label(:other), do: "Other"
  defp category_label(:topics), do: "Topics"
  defp category_label(:wiki), do: "Wiki"
end
