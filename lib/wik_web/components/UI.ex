defmodule WikWeb.Components.UI do
  import Iconify

  use WikWeb, :html

  attr :editing?, :boolean, required: true
  attr :rest, :global, include: ~w(phx-click data-testid aria-label)

  def editable_zone(assigns) do
    ~H"""
    <div class={["stacked"]}>
      {render_slot(@inner_block)}

      <button
        :if={@editing?}
        {@rest}
        type="button"
        aria-label="Edit space"
        class={[
          "border",
          "relative",
          "cursor-pointer",
          "rounded",
          "p-4",
          "w-[calc(100%+1rem)] -ml-[.5rem]",
          "h-[calc(100%+1rem)] -mt-[.5rem]",
          "border-accent/70 hover:border-accent transition-colors",
          "bg-accent/5 hover:bg-accent/10"
        ]}
      >
      </button>
    </div>
    """
  end

  attr :class, :string, default: "ml-0.5"
  attr :size_class, :string, default: "size-5"

  def icon_app(assigns) do
    ~H"""
    <.iconify icon="fluent:circle-multiple-concentric-16-filled" class={[@class, @size_class]} />
    """
  end

  attr :id, :string, default: "drawer"
  slot :inner_block, required: true
  slot :aside, required: true

  def drawer(assigns) do
    ~H"""
    <div class="drawer drawer-end md:drawer-open md:z-20">
      <input id={@id} type="checkbox" class="drawer-toggle" phx-update="ignore" />
      <div class="drawer-content">
        <WikWeb.Layouts.container>
          <div class="flex justify-end pt-2 h-0">
            <label
              :if={@aside != []}
              for={@id}
              class={[
                "btn btn-square ",
                "opacity-80 hover:opacity-100",
                "md:hidden"
              ]}
            >
              <.icon name="hero-bars-3" />
            </label>
          </div>
        </WikWeb.Layouts.container>
        {render_slot(@inner_block)}
      </div>

      <div class="drawer-side z-50">
        <label
          for={@id}
          aria-label="close sidebar"
          class="drawer-overlay"
        >
        </label>

        {render_slot(@aside)}
      </div>
    </div>
    """
  end

  slot :inner_block, required: true

  def separator(assigns) do
    ~H"""
    <div class="flex items-center opacity-20">
      <hr class="border-base-content w-full" />
      <span class="uppercase mx-4 text-sm">{render_slot(@inner_block)}</span>
      <hr class="border-base-content w-full" />
    </div>
    """
  end

  attr :count, :integer, required: true
  attr :color, :string, required: false
  attr :class, :string, default: ""

  def icon_document_with_count(assigns) do
    ~H"""
    <div class={[
      "indicator p-1",
      @class
    ]}>
      <.icon
        name="hero-book-open-micro"
        class="opacity-80"
        style={if assigns[:color], do: "color: color-mix(#{@color} 80%, var(--color-base-content))"}
      />
      <span
        class={[
          "indicator-item",
          "top-2 left-3",
          "opacity-70",
          "font-bold text-[11px]"
        ]}
        style={if assigns[:color], do: "color: color-mix(#{@color} 30%, var(--color-base-content))"}
      >
        {@count}
      </span>
    </div>
    """
  end

  attr :count, :integer, required: true
  attr :color, :string, required: false
  attr :class, :string, default: ""

  def icon_event_with_count(assigns) do
    ~H"""
    <div class={[
      "indicator p-1",
      @class
    ]}>
      <.icon
        name="hero-calendar-micro"
        class="opacity-80"
        style={if assigns[:color], do: "color: color-mix(#{@color} 80%, var(--color-base-content))"}
      />
      <span
        class={[
          "indicator-item",
          "top-2 left-3",
          "opacity-70",
          "font-bold text-[11px]"
        ]}
        style={if assigns[:color], do: "color: color-mix(#{@color} 30%, var(--color-base-content))"}
      >
        {@count}
      </span>
    </div>
    """
  end

  attr :count, :integer, required: true
  attr :color, :string, required: false
  attr :class, :string, default: ""

  def icon_user_with_count(assigns) do
    ~H"""
    <div class={[
      "indicator p-1",
      @class
    ]}>
      <.icon
        name="hero-user-micro"
        class="opacity-80"
        style={if assigns[:color], do: "color: color-mix(#{@color} 80%, var(--color-base-content))"}
      />
      <span
        class={[
          "indicator-item",
          "top-2 left-3",
          "opacity-70",
          "font-bold text-[11px]"
        ]}
        style={if assigns[:color], do: "color: color-mix(#{@color} 30%, var(--color-base-content))"}
      >
        {@count}
      </span>
    </div>
    """
  end

  attr :class, :string, default: ""
  slot :prepend, required: false

  def page_head(assigns) do
    ~H"""
    <header class={["mb-12", @class]}>
      <div class="mb-2 text-sm opacity-60 min-h-4">
        {render_slot(@prepend)}
      </div>
      {render_slot(@inner_block)}
    </header>
    """
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def panel_title(assigns) do
    ~H"""
    <h3 class={[
      "mb-2 text-xs uppercase tracking-wider text-base-content/60",
      "flex items-center gap-1",
      @class
    ]}>
      {render_slot(@inner_block)}
    </h3>
    """
  end

  defp step_id(id, index), do: "#{id}-step#{index}"

  attr :id, :string, required: true
  attr :class, :string, default: ""

  slot :step, required: true do
    attr :label, :string, required: true
  end

  slot :action do
    attr :step, :integer, required: true
  end

  def steps(assigns) do
    ~H"""
    <div class={["tabs [&_.tab]:hidden", @class]}>
      <%= for {step, index} <- Enum.with_index(@step, 1) do %>
        <input
          phx-update="ignore"
          id={step_id(@id, index)}
          type="radio"
          name={"#{@id}-steps"}
          class="tab"
          aria-label={step[:label]}
          checked={index == 1}
        />

        <div class="tab-content">
          {render_slot(step)}

          <% action = step_action(@action, index) %>
          <div class={[
            "mt-8 flex gap-4",
            cond do
              index == 1 -> "justify-end"
              index > 1 -> "justify-between"
              true -> nil
            end
          ]}>
            <label
              :if={index > 1}
              aria-label="Previous step"
              class="btn btn-xs btn-circle btn-primary btn-ghost"
              for={step_id(@id, index - 1)}
              title={"Go to step #{index - 1}"}
            >
              <.icon name="hero-chevron-left-mini" class="size-5" />
            </label>

            <label
              :if={index < length(@step) && !action}
              aria-label="Next step"
              class="btn btn-xs btn-circle btn-primary"
              for={step_id(@id, index + 1)}
              title={"Go to step #{index + 1}"}
            >
              <.icon name="hero-chevron-right-micro" class="size-4" />
            </label>

            <div :if={action}>
              {render_slot(action, %{next_step_id: step_id(@id, index + 1)})}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp step_action(actions, index) do
    Enum.find(actions, &(&1[:step] == index))
  end

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def page_title(assigns) do
    ~H"""
    <h1 class={[
      "text-2xl",
      "flex items-center gap-2",
      @class
    ]}>
      {render_slot(@inner_block)}
    </h1>
    """
  end

  # buttons ======================================================================

  attr :rest, :global, include: ~w(phx-click phx-target data-testid data-tip)

  def button_add_to_user(assigns) do
    ~H"""
    <button
      class={[
        "btn btn-sm btn-soft btn-accent btn-circle",
        "tooltip tooltip-xs tooltip-left tooltip-accent"
      ]}
      type="button"
      {@rest}
    >
      <div class="indicator">
        <div class="relative -left-0.5 top-0.5">
          <.icon name="hero-user-micro" class="opacity-70" />
          <.icon name="hero-plus-micro" class="indicator-item size-3 mt-0.5" />
        </div>
      </div>
    </button>
    """
  end

  attr :rest, :global, include: ~w(phx-click phx-target data-testid data-tip)

  def button_add_topic(assigns) do
    ~H"""
    <button
      class={[
        "btn btn-sm btn-soft btn-accent btn-circle",
        "tooltip tooltip-xs tooltip-left tooltip-accent"
      ]}
      type="button"
      {@rest}
    >
      <div class="indicator">
        <div class="relative -left-0.5 top-0.5">
          <.icon name="hero-tag-micro" class="opacity-70" />
          <.icon name="hero-plus-micro" class="indicator-item size-3 mt-0.5" />
        </div>
      </div>
    </button>
    """
  end

  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-target data-testid)

  def button_adjust(assigns) do
    ~H"""
    <button
      class={[
        "btn btn-xs btn-circle btn-accent btn-soft",
        @class
      ]}
      {@rest}
      type="button"
    >
      <.icon name="hero-cog-6-tooth-micro" class="size-3.5" />
    </button>
    """
  end

  attr :rest, :global, include: ~w(phx-click phx-target data-testid)

  def button_add(assigns) do
    ~H"""
    <button
      class="btn btn-xs btn-circle btn-accent btn-soft"
      {@rest}
    >
      <.icon name="hero-plus-micro" />
    </button>
    """
  end

  attr :rest, :global

  def button_relay(assigns) do
    ~H"""
    <button
      aria-label="Relay event"
      title="Relay event"
      class={["btn btn-sm btn-circle btn-accent btn-soft"]}
      {@rest}
    >
      <.iconify icon="mdi:share" class="size-5" />
    </button>
    """
  end

  attr :rest, :global

  def button_edit(assigns) do
    ~H"""
    <button
      class={["btn btn-sm btn-circle btn-accent btn-soft"]}
      {@rest}
    >
      <.icon name="hero-pencil-micro" />
    </button>
    """
  end

  attr :rest, :global
  attr :class, :string, default: ""

  def button_edit_soft(assigns) do
    ~H"""
    <button
      class={[
        "btn btn-xs btn-circle btn-accent btn-ghost",
        "text-accent hover:text-base-content",
        "opacity-60 hover:opacity-100",
        @class
      ]}
      type="button"
      {@rest}
    >
      <.icon name="hero-pencil-micro" />
    </button>
    """
  end

  attr :rest, :global, include: ~w(phx-click phx-target data-testid)

  def button_ok(assigns) do
    ~H"""
    <button
      class="btn btn-xs btn-circle btn-accent"
      {@rest}
    >
      <.icon name="hero-lock-open-micro" class="size-3.5" />
    </button>
    """
  end

  attr :rest, :global, include: ~w(phx-click phx-target data-testid)

  def button_unlock(assigns) do
    ~H"""
    <button
      class={[
        "btn btn-xs btn-circle btn-accent",
        "hover:text-base-content",
        "opacity-60 hover:opacity-100"
      ]}
      {@rest}
    >
      <.icon name="hero-lock-closed-micro" class="size-3.5" />
    </button>
    """
  end

  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-target data-testid)

  def button_plus(assigns) do
    ~H"""
    <button
      class={[
        "btn btn-accent btn-soft btn-circle btn-xs",
        @class
      ]}
      type="button"
      {@rest}
    >
      <.icon name="hero-plus-micro" />
    </button>
    """
  end

  # modal ======================================================================
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def modal_title(assigns) do
    ~H"""
    <h1 class={["text-xl", @class]}>
      {render_slot(@inner_block)}
    </h1>
    """
  end

  def modal_open(js \\ %JS{}, id), do: js |> JS.add_class("modal-open", to: "##{id}_modal")
  def modal_close(js \\ %JS{}, id), do: js |> JS.remove_class("modal-open", to: "##{id}_modal")

  attr :id, :string, required: true
  attr :full?, :boolean, default: false
  attr :open?, :boolean, default: false
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <.portal id={"#{@id}_portal"} target="body">
      <dialog id={"#{@id}_modal"} class={["modal", @open? && "modal-open"]}>
        <div
          class={[
            "modal-box",
            @full? && "w-[100svw] max-w-none h-[calc(100svh-1rem)] px-1 pt-7.5 pb-0.5"
          ]}
          phx-click-away={modal_close(@id)}
        >
          {render_slot(@inner_block)}

          <form method="dialog">
            <.modal_button_close phx-click={modal_close(@id)} />
          </form>
        </div>
      </dialog>
    </.portal>
    """
  end

  attr :rest, :global, include: ~w(phx-click phx-target data-testid)

  def modal_button_close(assigns) do
    ~H"""
    <button
      class={[
        "absolute right-2 top-2",
        "size-4 text-xs",
        "cursor-pointer",
        "opacity-50 hover:opacity-100 transition"
      ]}
      data-testid={@rest[:"data-testid"]}
      phx-click={@rest[:"phx-click"]}
      phx-target={@rest[:"phx-target"]}
    >
      ✕
    </button>
    """
  end
end
