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
          <span :if={@scope.tenant} class="font-bold tracking-wide opacity-50">
            / {@scope.tenant}
          </span>
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
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme-preference=here-now]_&]:left-1/3 [[data-theme-preference=here-now-dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="here-now"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="here-now-dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
