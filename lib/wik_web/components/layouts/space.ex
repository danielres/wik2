defmodule WikWeb.Layouts.Space do
  use WikWeb, :html

  embed_templates "layouts/*"

  alias WikWeb.Components
  alias WikWeb.Components.UI

  attr :scope, :map,
    default: %{actor: nil, tenant: nil},
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :editing?, :boolean, default: false
  attr :presences, :list, default: []
  attr :show_presences?, :boolean, default: false
  attr :view, :string, default: nil, doc: "the current view for active menu state"
  slot :actions, required: false
  slot :aside, required: false
  slot :inner_block, required: true

  def space(assigns) do
    ~H"""
    <%!-- TODO: fix presences rendering --%>
    <div
      :if={@show_presences? && @presences |> length() > 1}
      class={[
        "py-0",
        "group",
        "bg-base-300"
      ]}
    >
      <.container>
        <div
          class={[
            "flex gap-2 items-center justify-start",
            "tooltip tooltip-left",
            "overflow-x-auto"
          ]}
          data-tip={ "#{@presences |> length() } members online" }
        >
          <span class={[
            "text-xs small-caps text-base-content/50",
            "opacity-50 group-hover:opacity-100 transition-opacity"
          ]}>
            Online members:
          </span>
          <Components.Presences.avatars presences={@presences} tenant={@scope.tenant} />
        </div>
      </.container>
    </div>

    <div class={[
      "sticky top-0 z-30"
    ]}>
      <div class={[
        "bg-base-300",
        "border-y border-base-content/20 shadow"
      ]}>
        <.container>
          <.space_menu {assigns} />
        </.container>
      </div>

      <div class={[
        "flex justify-end self-end gap-4",
        "mr-4 h-0 relative top-4",
        @aside != [] && "md:right-74"
      ]}>
        <div class="space-y-2">
          <UI.button_drawer
            :if={@aside != [] && !@editing?}
            for="layout-space-drawer"
            class={["md:hidden"]}
          />
          <div :if={@actions != []}>{render_slot(@actions)}</div>
        </div>
      </div>
    </div>

    <UI.drawer id="layout-space-drawer">
      <:aside :if={@aside != []}>
        <div class={[
          "min-h-full",
          "min-h-full bg-base-300/80 backdrop-blur",
          "w-74",
          "space-y-3 py-4 px-4",
          "border-l border-base-content/20",
          "[&>*]:p-4",
          "[&>*]:bg-base-100",
          "[&>*]:border",
          "[&>*]:border-base-content/10",
          "[&>*]:rounded-box"
        ]}>
          <section :if={@view == "wiki"}>
            <.wiki_section {assigns} />
          </section>

          {render_slot(@aside)}
        </div>
      </:aside>

      <.container class={[
        "my-8 z-0",
        @actions != [] && "pt-6"
      ]}>
        {render_slot(@inner_block)}
      </.container>
    </UI.drawer>
    """
  end

  def container_class, do: "px-2 sm:pl-6 sm:pr-4 lg:pl-8 "

  attr :class, :any, default: ""
  slot :inner_block, required: true

  def container(assigns) do
    ~H"""
    <div class={container_class()}>
      <div class={[
        "max-md:mx-auto space-y-4",
        @class
      ]}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  def space_menu(assigns) do
    ~H"""
    <div class={[
      "grid",
      "grid-cols-[minmax(0,1fr)]",
      @editing? and "[&>a]:opacity-0 [&>a]:pointer-events-none"
    ]}>
      <div class={[
        "grid min-w-0 w-full",
        "grid-flow-col auto-cols-[minmax(3rem,1fr)]",
        "overflow-x-auto overflow-y-hidden",
        "[&>a]:flex",
        "[&>a]:gap-x-2",
        "[&>a]:justify-center",
        "[&>a]:max-sm:flex-col",
        "[&>a]:items-center",
        "[&>a]:py-2",
        "[&>a]:text-base-content/30",
        "[&>a]:transition",
        "[&>a:hover]:text-base-content",
        "[&>a_.icon]:text-base-content/30",
        "[&>a.active_.icon]:text-base-content/80",
        "[&>a.active]:text-base-content",
        "[&>a]:text-xs",
        "rounded"
      ]}>
        <.space_menu_link
          icon="hero-book-open-micro"
          item="wiki/home"
          label="Wiki"
          scope={@scope}
          view={@view}
        />

        <.space_menu_link
          icon="hero-tag-micro"
          item="topics"
          label="Topics"
          scope={@scope}
          view={@view}
        />

        <.space_menu_link
          icon="hero-calendar-days-micro"
          item="events"
          label="Events"
          scope={@scope}
          view={@view}
        />

        <.space_menu_link
          icon="hero-rectangle-stack-micro"
          item="libraries"
          label="Library"
          scope={@scope}
          view={@view}
        />

        <.space_menu_link
          icon="hero-user-micro"
          item="members"
          label="Members"
          scope={@scope}
          view={@view}
        />
      </div>
    </div>
    """
  end

  attr :icon, :string, default: "hero-book-open-micro"
  attr :view, :string, required: true
  attr :item, :string, required: true
  attr :label, :string, required: true
  attr :scope, :map, required: true

  def space_menu_link(assigns) do
    ~H"""
    <.link
      class={[@view == @item && "active"]}
      navigate={@view != @item && "/#{@scope.tenant.slug}/#{@item}"}
      patch={@view == @item && "/#{@scope.tenant.slug}/#{@item}"}
    >
      <.icon name={@icon} />
      <div class="small-caps">{@label}</div>
    </.link>
    """
  end

  def wiki_section(assigns) do
    ~H"""
    <UI.panel_title>
      <.icon name="hero-book-open-micro" class="opacity-70 size-4" /> Wiki
    </UI.panel_title>

    <ul class={[
      "text-sm",
      "[&_a]:cursor-pointer"
    ]}>
      <li>
        <.link
          class={[
            @view == "tree" and "!opacity-80 pointer-events-none"
          ]}
          navigate={~p"/#{@scope.tenant.slug}/tree"}
        >
          All pages
        </.link>
      </li>
    </ul>
    """
  end
end
