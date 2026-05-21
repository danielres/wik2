defmodule WikWeb.Layouts do
  import Iconify

  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use WikWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  alias WikWeb.Components

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """

  attr :view, :string, default: nil, doc: "the current view for active menu state"
  slot :inner_block, required: true

  def me(assigns) do
    ~H"""
    <div class={[
      "flex flex-wrap items-center justify-between gap-4",
      "px-2 sm:px-4 lg:px-8",
      "mb-8"
    ]}>
      <menu class={[]}>
        <ul class="menu menu-horizontal gap-1">
          <.menu_item view={@view} target="me">Settings</.menu_item>
          <.menu_item view={@view} target="me/access">Access</.menu_item>
          <.menu_item view={@view} target="me/tickets">Tickets</.menu_item>
        </ul>
      </menu>
    </div>

    <.container>
      {render_slot(@inner_block)}
    </.container>
    """
  end

  attr :scope, :map,
    default: %{actor: nil, tenant: nil},
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :view, :string, default: nil, doc: "the current view for active menu state"
  slot :inner_block, required: true

  def superadmin(assigns) do
    ~H"""
    <div class={[
      "flex flex-wrap items-center justify-between gap-4",
      "px-2 sm:px-4 lg:px-8",
      "mb-8"
    ]}>
      <menu class={[]}>
        <ul class="menu menu-horizontal gap-1">
          <li class={["bg-base-200 rounded", @view != "bot" and "opacity-40"]}>
            <.link patch={~p"/_"}>Bot</.link>
          </li>

          <li class={["bg-base-200 rounded", @view != "inbox" and "opacity-40"]}>
            <.link patch={~p"/_/inbox"}>Inbox</.link>
          </li>

          <li class={["bg-base-200 rounded", @view != "errors" and "opacity-40"]}>
            <.link patch={~p"/_/errors"}>Errors</.link>
          </li>
        </ul>
      </menu>
    </div>

    <.container width_class="">
      {render_slot(@inner_block)}
    </.container>
    """
  end

  attr :scope, :map,
    default: %{actor: nil, tenant: nil},
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :presences, :list, default: []
  attr :view, :string, default: nil, doc: "the current view for active menu state"
  slot :inner_block, required: true

  def space(assigns) do
    ~H"""
    <div class={[
      "sticky top-0 z-50"
    ]}>
      <div class={[
        "bg-base-300",
        "px-2 sm:px-4 lg:px-8",
        "flex gap-2",
        "[&>a]:rounded",
        "[&>a]:max-sm:flex-grow",
        "[&>a]:bg-base-300",
        "[&>a]:px-3",
        "[&>a]:py-2",
        "[&>a]:flex",
        "[&>a]:gap-1",
        "[&>a]:items-center",
        "[&>a]:text-xs",
        "[&>a]:justify-center",
        "[&>a]:font-bold",
        "[&>a]:opacity-40",
        "[&>a.active]:opacity-100",
        "[&_.icon]:size-4",
        "[&_.icon]:opacity-60",
        "[&_.dock-label]:opacity-70",
        "[&_.icon]:hidden"
      ]}>
        <.link patch={"/#{@scope.tenant.slug}/wiki"} class={@view == "wiki/home" and "active"}>
          <.icon name="hero-book-open-solid" />
          <span class="dock-label">Wiki</span>
        </.link>

        <.link patch={"/#{@scope.tenant.slug}/tags"} class={@view == "tags" and "active"}>
          <.icon name="hero-tag-solid" />
          <span class="dock-label">Tags</span>
        </.link>

        <.link patch={"/#{@scope.tenant.slug}/events"} class={@view == "events" and "active"}>
          <.icon name="hero-calendar-solid" />
          <span class="dock-label">Events</span>
        </.link>

        <.link patch={"/#{@scope.tenant.slug}/members"} class={@view == "members" and "active"}>
          <.icon name="hero-user-space-solid" />
          <span class="dock-label">Members</span>
        </.link>
      </div>
    </div>

    <div
      :if={@presences |> length() > 1}
      class={[
        "absolute",
        "right-2 sm:right-2",
        "w-[50svw]",
        "flex items-end",
        "z-40",
        "pt-0.5",
        "tooltip tooltip-left"
      ]}
      data-tip={ "#{@presences |> length() } members online" }
    >
      <div class={[
        "flex gap-1",
        "[&>:first-child]:ml-auto",
        "w-[50svw]",
        "overflow-x-auto"
      ]}>
        <Components.Presences.avatars presences={@presences} tenant={@scope.tenant} />
      </div>
    </div>

    <.container>
      {render_slot(@inner_block)}
    </.container>
    """
  end

  def menu_item(assigns) do
    ~H"""
    <li class={[
      "bg-base-200 rounded",
      @view != @target and "opacity-40"
    ]}>
      <.link :if={assigns[:tenant]} patch={"/#{@tenant.slug}/#{@target}"}>
        {render_slot(@inner_block)}
      </.link>

      <.link :if={assigns[:tenant] == nil} patch={"/#{@target}"}>
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end

  attr :width_class, :string, default: "max-w-3xl"
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def container(assigns) do
    ~H"""
    <main class="px-4 sm:px-6 lg:px-8 pt-16">
      <div class={[
        "mx-auto space-y-4",
        @width_class,
        @class
      ]}>
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :context, :map, default: %{claimable_sources: []}
  attr :tenant_context, :map, default: nil

  attr :scope, :map, default: %{actor: nil, tenant: nil}

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="grid grid-rows-[auto_1fr_auto] min-h-screen">
      <header class="navbar px-2 sm:px-4 lg:px-8 bg-base-300/50 py-2 sm:py-3 min-h-0">
        <div class="flex-1 flex items-center gap-0">
          <.link navigate={~p"/"} class="opacity-50 hover:opacity-100" aria-label="Home">
            <.iconify icon="fluent:circle-multiple-concentric-16-filled" class="size-4" />
          </.link>

          <.icon :if={@scope.tenant} name="hero-chevron-right-mini" class="size-4 opacity-20 mx-1" />

          <div
            :if={@scope.tenant}
            class={[
              "max-w-[calc(100svw-9rem)] overflow-hidden truncate",
              "opacity-60 hover:opacity-100 transition text-sm"
            ]}
          >
            <.link navigate={~p"/#{@scope.tenant.slug}"}>
              {@scope.tenant |> to_string()}
            </.link>
          </div>
        </div>

        <div>
          <button
            class={[
              "opacity-80 hover:opacity-100 transition cursor-pointer",
              "relative"
            ]}
            popovertarget="popover-user-dropdown"
            style="anchor-name:--anchor-user-dropdown"
          >
            <Components.User.avatar
              membership={@tenant_context && @tenant_context[:current_membership]}
              tenant={@scope.tenant}
              size="sm"
            />

            <div
              :if={@context.claimable_sources != []}
              class={[
                "status status-accent animate-ping",
                "absolute top-0 left-0"
              ]}
            >
            </div>
          </button>

          <div
            class={[
              "min-w-36",
              "dropdown dropdown-end mt-1",
              "bg-base-300 dark:shadow-lg",
              "shadow",
              "border border-base-content/30",
              "rounded-box",
              "p-2"
            ]}
            popover
            id="popover-user-dropdown"
            style="position-anchor:--anchor-user-dropdown"
          >
            <ul
              :if={@context.claimable_sources != []}
              class={[
                "menu w-full",
                "border-b-1 border-base-content/20"
              ]}
            >
              <li>
                <.link
                  class="btn btn-sm btn-soft btn-accent border"
                  navigate={~p"/auth/telegram"}
                >
                  <span class="font-bold">New sources</span>
                  <.icon name="hero-chevron-right-micro" />
                </.link>
              </li>
            </ul>

            <ul class={[
              "menu w-full"
            ]}>
              <li>
                <.link navigate={~p"/sign-out"} class="">
                  <.icon name="hero-arrow-right-on-rectangle" /> Log out
                </.link>
              </li>

              <li>
                <.link navigate={~p"/me"} class="opacity-80 hover:opacity-100 transition">
                  <.icon name="hero-user" /> Account
                </.link>
              </li>
            </ul>

            <ul
              :if={
                @scope.tenant && @tenant_context &&
                  @tenant_context[:current_membership] &&
                  @tenant_context[:current_membership].username != nil
              }
              class={[
                "menu w-full",
                "border-t-1 border-base-content/20"
              ]}
            >
              <li>
                <.link navigate={
                  ~p"/#{@scope.tenant.slug}/wiki/members/#{@tenant_context[:current_membership].username}"
                }>
                  <.icon name="hero-face-smile" /> Profile
                </.link>
              </li>
            </ul>

            <ul class={[
              "py-2",
              "border-t-1 border-base-content/20"
            ]}>
              <li>
                <div class="w-min mx-auto">
                  <WikWeb.Layouts.theme_toggle />
                </div>
              </li>
            </ul>

            <ul
              :if={@scope.actor && @scope.actor.role == :superadmin}
              class={[
                "menu w-full",
                "border-t-1 border-base-content/20"
              ]}
            >
              <li>
                <.link navigate={~p"/_"}>
                  <span class="badge badge-error">Superadmin</span>
                </.link>
              </li>
            </ul>
          </div>
        </div>
      </header>

      <div class="mb-8">
        {render_slot(@inner_block)}
      </div>

      <footer>
        <div class="">
          <div class="hidden">
            <%= if @scope.actor do %>
              Privacy and moderation requests can be submitted <.link
                class="link link-hover font-medium"
                navigate={~p"/me/tickets/new"}
              >
              in-app while logged in
            </.link>.
            <% else %>
              Privacy and moderation requests are handled in-app for logged-in users. If you cannot
              access your account, use the recovery path shared with your space operator.
            <% end %>
          </div>

          <div class={[
            "flex justify-center gap-6 text-xs mt-4 mb-1",
            "[&_a]:flex [&_a]:items-center [&_a]:gap-1",
            "[&_a]:opacity-30 hover:[&_a]:opacity-70 [&_a:hover]:opacity-100 [&_a]:transition",
            "[&_.icon]:size-3"
          ]}>
            <.link :if={false} navigate={~p"/about"}>
              <.icon name="hero-information-circle-micro" />
              <span>about</span>
            </.link>

            <.link navigate={~p"/terms"}>
              <.icon name="hero-document-text-micro" />
              <span>terms</span>
            </.link>

            <.link navigate={~p"/privacy"}>
              <.icon name="hero-lock-closed-micro" />
              <span>privacy</span>
            </.link>

            <.link
              href="https://github.com/danielres/wik2"
              target="_blank"
              rel="noopener"
              class="space"
            >
              <.icon name="hero-code-bracket-micro" class="space-hover:hidden" />
              <.icon
                name="hero-arrow-top-right-on-square-micro"
                class="hidden space-hover:inline-block"
              />
              <span>github</span>
            </.link>
          </div>
        </div>
      </footer>
    </div>

    <Components.Modal.render
      :if={@tenant_context && @tenant_context[:membership_username_form] != nil}
      open?={true}
      testid="membership-username-dialog"
    >
      <Components.Membership.steps
        form={@tenant_context[:membership_username_form]}
        space={@scope.tenant}
      />
    </Components.Modal.render>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("Connection lost")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Reconnecting...")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Starting server")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Reconnecting...")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides a system, light, and dark theme toggle.

  The toggle only deals in semantic modes and leaves the concrete daisyUI
  theme names to the root layout bootstrap.
  """
  @theme_modes [
    %{label: "System", icon: "hero-computer-desktop-micro", mode: "system"},
    %{label: "Light", icon: "hero-sun-micro", mode: "light"},
    %{label: "Dark", icon: "hero-moon-micro", mode: "dark"}
  ]

  def theme_toggle(assigns) do
    assigns = assign(assigns, :theme_modes, @theme_modes)

    ~H"""
    <div
      id="theme-toggle"
      class="card relative flex flex-row items-center rounded-full border-2 border-base-200 bg-base-300 p-1"
      role="group"
      aria-label="Theme selector"
    >
      <div class={[
        "pointer-events-none absolute inset-y-1 left-1 w-[calc(33.333%-0.25rem)] rounded-full border border-base-200 bg-base-100 brightness-110 transition-[left]",
        "[[data-theme-mode=light]_&]:left-[calc(33.333%+0.125rem)]",
        "[[data-theme-mode=dark]_&]:left-[calc(66.666%+0.125rem)]"
      ]} />

      <button
        :for={theme <- @theme_modes}
        type="button"
        class="group relative z-10 flex w-1/3 cursor-pointer justify-center rounded-full p-2"
        data-theme-toggle
        data-theme-mode={theme.mode}
        title={theme.label}
        aria-label={theme.label}
      >
        <.icon
          name={theme.icon}
          class="size-4 opacity-75 transition-opacity group-hover:opacity-100"
        />
      </button>
    </div>
    """
  end
end
