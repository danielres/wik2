defmodule QblogWeb.Components.Modal do
  use Phoenix.Component

  attr :"phx-target", :any, required: false
  attr :cancel, :string, required: false
  attr :open?, :boolean, default: true
  slot :inner_block, required: true
  slot :title, required: false

  def render(assigns) do
    ~H"""
    <dialog
      class={["modal", @open? and "modal-open"]}
      phx-key="escape"
      phx-target={assigns[:"phx-target"]}
      phx-window-keydown={@cancel}
    >
      <div
        :if={@open?}
        class={["modal-box", "min-w-sm", "bg-base-200"]}
        phx-click-away={@cancel}
        phx-target={assigns[:"phx-target"]}
      >
        <button
          phx-click={@cancel}
          phx-target={assigns[:"phx-target"]}
          class={[
            "absolute right-2 top-2",
            "size-4 text-xs",
            "cursor-pointer",
            "opacity-50 hover:opacity-100 transition"
          ]}
        >
          ✕
        </button>

        <h3 :if={@title != []} class="mb-2">{render_slot(@title)}</h3>

        {render_slot(@inner_block)}
      </div>
    </dialog>
    """
  end
end
