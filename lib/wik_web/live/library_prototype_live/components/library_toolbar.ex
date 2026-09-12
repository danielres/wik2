defmodule WikWeb.LibraryPrototypeLive.Components.LibraryToolbar do
  use WikWeb, :html

  alias WikWeb.Components.UI

  attr :active_topics, :list, required: true
  attr :active_types, :list, required: true
  attr :can_create_entry?, :boolean, required: true
  attr :can_manage_types?, :boolean, required: true
  attr :space_slug, :string, required: true
  attr :topics, :list, required: true
  attr :types, :list, required: true

  def render(assigns) do
    ~H"""
    <header class="flex flex-wrap items-end justify-between gap-3" data-testid="library-toolbar">
      <div class="flex flex-wrap items-center gap-2" data-testid="library-filters">
        <.filter_menu
          icon="hero-circle-stack-micro"
          items={@types}
          kind="type"
          selected_ids={Enum.map(@active_types, & &1.id)}
          testid="type-filter"
          title="Types"
        />

        <.filter_menu
          icon="hero-tag-micro"
          items={@topics}
          kind="topic"
          selected_ids={Enum.map(@active_topics, & &1.id)}
          testid="topic-filter"
          title="Topics"
        />

        <button
          :for={type <- @active_types}
          class={[
            "badge badge-sm",
            "gap-1",
            "bg-base-content/10",
            "opacity-50 hover:opacity-100 transition",
            "cursor-pointer",
            "group"
          ]}
          data-testid={"active-type-filter-#{type.slug}"}
          phx-click="filter:toggle"
          phx-value-id={type.id}
          phx-value-kind="type"
          type="button"
        >
          {type.name}
          <.icon
            name="hero-x-mark-micro"
            class={[
              "size-3",
              "opacity-50 group-hover:opacity-100"
            ]}
          />
        </button>

        <button
          :for={topic <- @active_topics}
          class={[
            "badge badge-sm",
            "gap-1",
            "bg-primary/10",
            "text-primary",
            "opacity-80 hover:opacity-100 transition",
            "cursor-pointer",
            "group"
          ]}
          data-testid={"active-topic-filter-#{topic.slug}"}
          phx-click="filter:toggle"
          phx-value-id={topic.id}
          phx-value-kind="topic"
          type="button"
        >
          {topic.name}
          <.icon
            name="hero-x-mark-micro"
            class={[
              "size-3",
              "opacity-50 group-hover:opacity-100"
            ]}
          />
        </button>
      </div>
      <div class="flex items-center gap-2">
        <UI.action_button
          :if={@can_manage_types?}
          data-tip="Settings"
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
      class="btn btn-sm"
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
        "menu z-20 max-h-72 w-56",
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
            name={
              if(@selected_ids == [] or item.id in @selected_ids,
                do: "hero-check-micro",
                else: "hero-minus-micro"
              )
            }
            class={
              if(@selected_ids == [] or item.id in @selected_ids,
                do: "text-success",
                else: "opacity-20"
              )
            }
          />
          <span class="truncate">{item.name}</span>
        </button>
      </li>
    </ul>
    """
  end
end
