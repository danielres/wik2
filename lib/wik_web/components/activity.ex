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
      aria-label="Filter activity by category"
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

  attr :empty_message, :string, default: "No activity in this category yet."
  attr :id, :string, required: true
  attr :page_size, :any, required: true
  attr :query, :any, required: true
  attr :scope, :any, required: true
  attr :search, :any, default: nil
  attr :show_pagination, :boolean, default: true
  attr :show_sort, :boolean, default: true
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
        <:col :let={entry} field="actor_label" label="" class="w-0 align-baseline pt-[0.90rem]">
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

  attr :class, :any, default: []
  attr :empty_message, :string, default: "No activity yet."
  attr :id, :string, required: true
  attr :page_size, :integer, default: 25
  attr :query, :any, required: true
  attr :scope, :any, required: true
  attr :show_space?, :boolean, default: false
  attr :user_tz, :string, required: true
  attr :view_all_path, :string, default: nil

  def preview(assigns) do
    loads = [
      :event_starts_at,
      actor_membership: [:avatar_url, :space, user: [:external_identities]]
    ]

    loads = if assigns.show_space?, do: [:space | loads], else: loads
    assigns = assign(assigns, :loads, loads)

    ~H"""
    <section id={"#{@id}-section"} class={@class}>
      <Components.UI.panel_title class="justify-between">
        <span class="flex gap-2">
          <.icon name="hero-arrow-path-micro" class="opacity-50" /> Activity
        </span>
        <.link
          :if={@view_all_path}
          class="normal-case tracking-normal hover:text-base-content transition-colors"
          id={"#{@id}-view-all"}
          navigate={@view_all_path}
        >
          View all <.icon name="hero-arrow-right-micro" class="size-3" />
        </.link>
      </Components.UI.panel_title>

      <div id={"#{@id}-preview"} class="max-h-[32rem] overflow-y-auto overflow-x-hidden">
        <Cinder.collection
          empty_message={@empty_message}
          id={"#{@id}-preview-collection"}
          layout={:list}
          page_size={@page_size}
          query={@query}
          query_opts={[load: @loads]}
          scope={@scope}
          show_filters={false}
          show_pagination={false}
          show_sort={false}
          theme={WikWeb.Cinder.Themes.Dense}
        >
          <:item :let={entry}>
            <.row entry={entry} show_space?={@show_space?} user_tz={@user_tz} />
          </:item>

          <:col :if={false} field="occurred_at" label="When" sort></:col>
        </Cinder.collection>
      </div>
    </section>
    """
  end

  attr :entry, :map, required: true
  attr :show_space?, :boolean, default: false
  attr :user_tz, :string, default: "Etc/UTC"

  def row(assigns) do
    ~H"""
    <div
      class={[
        "rounded p-3",
        "bg-base-200/70"
      ]}
      data-testid={"activity-entry-#{@entry.id}"}
    >
      <div class="flex gap-3 items-baseline">
        <.actor entry={@entry} />

        <.summary entry={@entry} />
      </div>

      <.note entry={@entry} />

      <div class={["flex gap-3 items-center", "mt-2"]}>
        <.link
          :if={@show_space?}
          class={[
            "block text-right",
            "text-sm",
            "opacity-50 hover:opacity-100 transition"
          ]}
          data-testid={"activity-space-#{@entry.space_id}"}
          navigate={"/#{@entry.space.slug}"}
        >
          {@entry.space.name}
        </.link>

        <div class="flex shrink-0 items-center gap-2 text-xs ml-auto">
          <%!-- <span :if={@entry.occurrence_count > 1} class="badge badge-ghost badge-xs"> --%>
          <%!--   ×{@entry.occurrence_count} --%>
          <%!-- </span> --%>
          <Components.Time.relative_and_precise
            ago?
            datetime={@entry.occurred_at}
            user_tz={@user_tz}
          />
        </div>
      </div>
    </div>
    """
  end

  attr :entry, :map, required: true
  attr :name?, :boolean, default: false

  def actor(assigns) do
    ~H"""
    <Components.User.identity
      :if={match?(%Membership{}, @entry.actor_membership)}
      avatar_size="xs"
      class="max-w-36 text-xs"
      link?
      name?={@name?}
      membership={@entry.actor_membership}
    />

    <span
      :if={!match?(%Membership{}, @entry.actor_membership)}
      class="flex items-center gap-1 text-xs text-base-content/65"
    >
      <span class="grid size-4 place-items-center rounded-full bg-base-300">
        <.icon name="hero-user-micro" class="size-3" />
      </span>
      <%= if @name? do %>
        {@entry.actor_label || "Someone"}
      <% end %>
    </span>
    """
  end

  attr :entry, :map, required: true

  def summary(assigns) do
    targets = summary_targets(assigns.entry)

    assigns =
      assigns
      |> assign(:prefix, summary_prefix(assigns.entry, length(targets)))
      |> assign(:suffix_highlight, summary_suffix_highlight(assigns.entry))
      |> assign(:suffix, summary_suffix(assigns.entry))
      |> assign(:targets, Enum.with_index(targets))
      |> assign(:target_count, length(targets))
      |> assign(:timing, event_timing(assigns.entry))

    ~H"""
    <p class="text-sm leading-snug">
      <span class="opacity-90">{@prefix}</span>
      <%= if @targets == [] do %>
        <.link
          :if={@entry.subject_path}
          navigate={@entry.subject_path}
          class="font-bold hover:underline text-primary"
        >
          {@entry.subject_label}
        </.link>
        <span :if={!@entry.subject_path} class="font-bold">{@entry.subject_label}</span>
      <% else %>
        <span :for={{target, index} <- @targets}>
          {target_separator(index, @target_count)}<.link
            :if={target.path}
            class="font-bold hover:underline text-primary"
            data-testid={"activity-target-#{target.id}"}
            navigate={target.path}
          >{target.label}</.link>
          <span
            :if={!target.path}
            class="font-bold"
            data-testid={"activity-target-#{target.id}"}
          >
            {target.label}
          </span>
        </span>
      <% end %>
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

  defp summary_prefix(%{kind: :page_created}, count) when count > 1, do: "created pages "
  defp summary_prefix(%{kind: :page_deleted}, count) when count > 1, do: "deleted pages "
  defp summary_prefix(%{kind: :page_updated}, count) when count > 1, do: "updated pages "
  defp summary_prefix(%{kind: :topic_created}, count) when count > 1, do: "created topics "
  defp summary_prefix(%{kind: :topic_deleted}, count) when count > 1, do: "deleted topics "
  defp summary_prefix(%{kind: :topic_updated}, count) when count > 1, do: "updated topics "
  defp summary_prefix(entry, _target_count), do: summary_prefix(entry)

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

  defp summary_targets(%{kind: kind} = entry)
       when kind in [
              :page_created,
              :page_deleted,
              :page_updated,
              :topic_created,
              :topic_deleted,
              :topic_updated
            ] do
    case metadata_value(entry, :targets) do
      targets when is_list(targets) -> Enum.map(targets, &normalize_target/1)
      _targets -> []
    end
  end

  defp summary_targets(_entry), do: []

  defp normalize_target(target) do
    %{
      id: Map.get(target, :id) || Map.get(target, "id"),
      label: Map.get(target, :label) || Map.get(target, "label"),
      path: Map.get(target, :path) || Map.get(target, "path")
    }
  end

  defp target_separator(0, _count), do: ""
  defp target_separator(index, 2) when index == 1, do: " and "
  defp target_separator(index, count) when index == count - 1, do: ", and "
  defp target_separator(_index, _count), do: ", "

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
