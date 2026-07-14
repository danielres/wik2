defmodule WikWeb.Layouts.Space do
  import Iconify

  use WikWeb, :html

  embed_templates "layouts/*"

  alias WikWeb.Components
  alias WikWeb.Components.UI
  alias WikWeb.TenantContext

  attr :scope, :map,
    default: %{actor: nil, tenant: nil},
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :presences, :list, default: []
  attr :view, :string, default: nil, doc: "the current view for active menu state"
  attr :editing?, :boolean, default: false
  slot :inner_block, required: true
  slot :actions, required: false
  slot :aside, required: false

  def space(assigns) do
    ~H"""
    <div
      :if={@presences |> length() > 1}
      class={[
        "py-0",
        "-mt-2",
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
      "sticky top-0 z-30",
      "bg-base-300",
      "border-y border-base-content/20 shadow-lg"
    ]}>
      <.container>
        <.space_menu {assigns} />
      </.container>
    </div>

    <UI.drawer>
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

      <.container class="my-8 max-w-3xl z-0">
        {render_slot(@inner_block)}
      </.container>
    </UI.drawer>
    """
  end

  def container_class, do: "px-2 sm:pl-6 sm:pr-4 lg:pl-8 "

  attr :class, :string, default: ""
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
      "grid-cols-[1fr_1fr_1fr_1fr_auto]",
      "items-center",
      "[&>a]:justify-center",
      "[&>*]:min-h-10",
      "[&>a+a]:border-r",
      "sm:[&>a:first-child]:border-x",
      "max-sm:[&>a:first-child]:border-r",
      "[&>*]:py-2",
      "[&>a]:text-center",
      "[&>a]:border-base-content/15",
      "[&>a]:text-xs",
      "sm:[&>a]:text-sm",
      "[&>a]:sm:flex",
      "[&>a]:sm:gap-2",
      "[&>a]:sm:items-center",
      "[&>a>div]:opacity-50",
      "[&>a.active>div]:opacity-70",
      "[&>a:hover>div]:opacity-70",
      "[&>a>.icon]:opacity-20",
      "[&>a:hover>.icon]:opacity-100",
      "[&>a.active>.icon]:opacity-100",
      "max-sm:[&>a]:px-4",
      @editing? and "[&>a]:opacity-0 [&>a]:pointer-events-none"
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
        icon="hero-calendar-micro"
        item="events"
        label="Events"
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

      <div class={[
        "pl-2 sm:pl-4 min-w-12 flex justify-end gap-3",
        @actions == [] && "opacity-0 pointer-events-none"
      ]}>
        {render_slot(@actions)}
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
