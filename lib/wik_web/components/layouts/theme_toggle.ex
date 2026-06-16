defmodule WikWeb.Layouts.ThemeToggle do
  use WikWeb, :html

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
      class="card relative flex flex-row items-center rounded-full border-2 border-base-200 bg-base-200 p-1 gap-1"
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
          class="size-3.5 opacity-75 transition-opacity group-hover:opacity-100"
        />
      </button>
    </div>
    """
  end
end
