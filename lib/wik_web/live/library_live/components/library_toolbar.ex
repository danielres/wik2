defmodule WikWeb.LibraryLive.Components.LibraryToolbar do
  use WikWeb, :html

  alias WikWeb.Components.UI

  def button_type(assigns) do
    ~H"""
    <button
      class={[
        "bg-base-300/60 hover:bg-base-300/100 transition",
        "px-3 py-0.5 rounded",
        "cursor-pointer",
        (Enum.empty?(@active_type_ids) or @type.id in @active_type_ids) && "opacity-100",
        (@active_type_ids != [] and @type.id not in @active_type_ids) &&
          "opacity-50 hover:opacity-80"
      ]}
      data-testid={"type-filter-#{@type.slug}"}
      phx-click="filter:toggle"
      phx-value-id={@type.id}
      phx-value-kind="type"
      type="button"
    >
      <span class="uppercase tracking-wider text-[12px] font-semibold opacity-80">
        {@type.name |> String.replace("External", "Ext.")}
      </span>
    </button>
    """
  end

  def button_topics_clear(assigns) do
    ~H"""
    <button
      :if={@active_topics |> length() > 1}
      aria-label="Clear topic filters"
      class={[
        "badge badge-sm aspect-square p-0",
        "gap-1",
        "bg-base-300",
        "opacity-80 hover:opacity-100 transition",
        "cursor-pointer",
        "group"
      ]}
      data-testid="active-topic-filters-clear"
      phx-click="filter:clear"
      phx-value-kind="topic"
      type="button"
    >
      <.icon
        name="hero-x-mark-micro"
        class={[
          "size-3",
          "opacity-70 group-hover:opacity-100"
        ]}
      />
    </button>
    """
  end

  def button_topic(assigns) do
    ~H"""
    <button
      class={[
        "badge badge-sm",
        "gap-1",
        "bg-base-content/10",
        "opacity-80 hover:opacity-100 transition",
        "cursor-pointer",
        "group"
      ]}
      data-testid={"active-topic-filter-#{@topic.slug}"}
      phx-click="filter:toggle"
      phx-value-id={@topic.id}
      phx-value-kind="topic"
      type="button"
    >
      {@topic.name}
      <.icon
        name="hero-x-mark-micro"
        class={[
          "size-3",
          "opacity-50 group-hover:opacity-100"
        ]}
      />
    </button>
    """
  end

  def panel_settings(assigns) do
    ~H"""
    <ul>
      <li>
        <.link data-testid="types-manage-open" patch={~p"/#{@space_slug}/libraries/types"}>
          <.icon name="hero-circle-stack-micro" class="opacity-40" />
          <span>Types</span>
        </.link>
      </li>
      <li>
        <.link
          data-testid="topic-matching-open"
          patch={~p"/#{@space_slug}/libraries/topic-matching"}
        >
          <.icon name="hero-sparkles-micro" class="opacity-40" />
          <span>Smart topics</span>
        </.link>
      </li>
    </ul>
    """
  end

  attr :active_topics, :list, required: true
  attr :active_types, :list, required: true
  attr :can_create_entry?, :boolean, required: true
  attr :can_manage_types?, :boolean, required: true
  attr :space_slug, :string, required: true
  attr :topics, :list, required: true
  attr :types, :list, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign(:active_type_ids, Enum.map(assigns.active_types, & &1.id))
      |> assign(:sorted_types, Enum.sort_by(assigns.types, &String.downcase(&1.name)))

    ~H"""
    <header class="flex flex-wrap items-baseline justify-between gap-3" data-testid="library-toolbar">
      <div class="space-y-4" data-testid="library-filters">
        <div class="flex flex-wrap gap-x-1 gap-y-0.5" data-testid="type-filters">
          <.button_type :for={type <- @sorted_types} type={type} {assigns} />
        </div>

        <div class="flex flex-wrap items-center gap-1">
          <.filter_menu
            icon="hero-tag-micro"
            items={@topics}
            kind="topic"
            selected_ids={Enum.map(@active_topics, & &1.id)}
            testid="topic-filter"
            title="Topics"
          />

          <.button_topics_clear {assigns} />
          <.button_topic :for={topic <- @active_topics} topic={topic} {assigns} />
        </div>
      </div>

      <div class="flex items-center gap-2 ml-auto">
        <UI.action_button
          :if={@can_manage_types?}
          data-tip="Library settings"
          icon="hero-adjustments-horizontal-micro"
          data-testid="library-settings-open"
          popovertarget="library-settings-popover"
          class="[anchor-name:--library-settings-anchor]"
        />

        <div
          :if={@can_manage_types?}
          class={[
            "dropdown dropdown-end z-20",
            "menu w-48 rounded-box",
            "bg-base-300"
          ]}
          id="library-settings-popover"
          popover
          style="position-anchor:--library-settings-anchor"
        >
          <UI.panel_title>Settings</UI.panel_title>
          <.panel_settings {assigns} />
        </div>

        <UI.action_button
          :if={@can_create_entry?}
          data-tip="Add entry"
          icon="hero-plus-micro"
          data-testid="entry-create-open"
          phx-click="entry:new"
        />
      </div>
    </header>
    """
  end

  attr :icon, :string, required: true
  attr :items, :list, required: true
  attr :kind, :string, required: true
  attr :selected_ids, :list, required: true
  attr :testid, :string, required: true
  attr :title, :string, required: true

  defp filter_menu(assigns) do
    ~H"""
    <button
      class="btn btn-xs rounded-full"
      data-testid={@testid}
      popovertarget={"#{@testid}-popover"}
      style={"anchor-name:--#{@testid}-anchor"}
      type="button"
    >
      <.icon name={@icon} class="opacity-40" />
      <span class="small-caps">{@title}</span>
      <.icon name="hero-chevron-down-micro" class="opacity-60" />
    </button>

    <ul
      class={[
        "dropdown",
        "mt-1",
        "menu menu-sm z-20 max-h-64 w-56",
        "overflow-y-auto rounded-box bg-base-300"
      ]}
      id={"#{@testid}-popover"}
      popover
      style={"position-anchor:--#{@testid}-anchor"}
    >
      <li :for={item <- @items}>
        <button
          data-testid={"#{@testid}-#{item.slug}"}
          phx-click="filter:toggle"
          phx-value-id={item.id}
          phx-value-kind={@kind}
          type="button"
        >
          <.icon
            name="hero-check-micro"
            class={
              if(@selected_ids == [] or item.id in @selected_ids,
                do: "text-success",
                else: "opacity-20"
              )
            }
          />
          <span class="truncate">{item.name}</span>
          <span class="badge badge-xs opacity-70">{item.entry_count}</span>
        </button>
      </li>
    </ul>
    """
  end
end
