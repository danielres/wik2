defmodule QblogWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use QblogWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

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

  attr :scope, :map,
    default: %{tenant: nil, user: nil},
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def group(assigns) do
    ~H"""
    <menu class=" px-2 sm:px-6 lg:px-8">
      <ul class="flex flex-wrap gap-1">
        <li><.menu_button {assigns} target="wiki">Wiki</.menu_button></li>
        <li><.menu_button {assigns} target="tree">Page tree</.menu_button></li>
        <li><.menu_button {assigns} target="blog">Blog</.menu_button></li>
      </ul>
    </menu>

    <.container>
      {render_slot(@inner_block)}
    </.container>
    """
  end

  def container(assigns) do
    ~H"""
    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-2xl space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>
    """
  end

  def menu_button(assigns) do
    ~H"""
    <.link
      class={[
        "px-4 py-1",
        "rounded",
        "bg-base-300",
        "font-bold",
        "text-sm",
        "opacity-75 hover:opacity-100 transition"
      ]}
      navigate={"/#{@scope.tenant}/#{@target}"}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :scope, :map,
    default: %{tenant: nil, user: nil},
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-2 sm:px-6 lg:px-8">
      <div class="flex-1">
        <div class="flex-1 flex w-fit items-center">
          <.link navigate={~p"/"} class="btn btn-circle btn-sm opacity-50 hover:opacity-100">
            <i class="hero-home-mini size-4" />
          </.link>
          <.link
            :if={@scope.tenant}
            class="font-bold tracking-wide opacity-50 hover:opacity-100 transition"
            navigate={~p"/#{@scope.tenant.name}"}
          >
            / {@scope.tenant |> to_string()}
          </.link>
        </div>
      </div>

      <div>
        <ul class="flex flex-column px-1 space-x-4 items-center">
          <li class="flex gap-2 items-center">
            <.link navigate={~p"/me"} class="opacity-50 hover:opacity-100">
              {@scope.actor |> to_string()}
            </.link>

            <.link navigate={~p"/sign-out"} class="btn btn-ghost btn-square rounded-full">
              <.icon
                name="hero-arrow-right-on-rectangle"
                class="size-4 opacity-75 hover:opacity-100"
              />
            </.link>
          </li>
        </ul>
      </div>
    </header>

    {render_slot(@inner_block)}

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
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
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
      class="card relative flex flex-row items-center rounded-full border-2 border-base-200 bg-base-200 p-1"
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
