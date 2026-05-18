defmodule WikWeb.Components.UI do
  use WikWeb, :html

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
            index == 1 && "justify-end",
            index == length(@step) && "justify-between",
            index > 1 && index < length(@step) && "justify-between"
          ]}>
            <label
              :if={index > 1}
              aria-label="Previous step"
              class="btn btn-xs btn-circle btn-primary btn-ghost"
              for={step_id(@id, index - 1)}
              title={"Go to step #{index - 1}"}
            >
              <.icon name="hero-chevron-left-micro" class="size-4" />
            </label>

            <label
              :if={index < length(@step)}
              aria-label="Next step"
              class="btn btn-xs btn-circle btn-primary"
              for={step_id(@id, index + 1)}
              title={"Go to step #{index + 1}"}
            >
              <.icon name="hero-chevron-right-micro" class="size-4" />
            </label>

            <div :if={action}>
              {render_slot(action)}
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
      @class
    ]}>
      {render_slot(@inner_block)}
    </h1>
    """
  end

  attr :rest, :global, include: ~w(phx-click phx-target data-testid)

  def button_plus(assigns) do
    ~H"""
    <button
      class="btn btn-accent btn-circle btn-xs"
      {@rest}
    >
      <.icon name="hero-plus-micro" />
    </button>
    """
  end

  slot :body, required: true
  slot :title, required: false
  slot :actions, required: false

  def page_blocks(assigns) do
    ~H"""
    <section>
      <div :if={@title != []} class="flex items-center justify-between mb-1">
        <h2 class="text-lg">
          {render_slot(@title)}
        </h2>

        <div :if={@actions != []}>
          {render_slot(@actions)}
        </div>
      </div>

      <div class="space-y-2">
        <div :for={body <- @body} class="card bg-base-200 h-min">
          <div class="card-body p-2">
            {render_slot(body)}
          </div>
        </div>
      </div>
    </section>
    """
  end

  # modal ======================================================================

  def modal_open(js \\ %JS{}, id), do: js |> JS.add_class("modal-open", to: "##{id}_modal")
  def modal_close(js \\ %JS{}, id), do: js |> JS.remove_class("modal-open", to: "##{id}_modal")

  attr :id, :string, required: true
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <dialog id={"#{@id}_modal"} class="modal">
      <div class="modal-box" phx-click-away={modal_close(@id)}>
        {render_slot(@inner_block)}

        <form method="dialog">
          <.modal_button_close phx-click={modal_close(@id)} />
        </form>
      </div>
    </dialog>
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
