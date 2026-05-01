defmodule QblogWeb.Components.Modal do
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  attr :"phx-target", :any, required: false
  attr :bg_class, :string, default: "bg-base-100"
  attr :cancel, :string, required: false
  attr :cancel_testid, :string, default: nil
  attr :full_height?, :boolean, default: false
  attr :open?, :boolean, default: true
  attr :testid, :string, default: nil
  slot :inner_block, required: true
  slot :title, required: false

  def render(assigns) do
    ~H"""
    <dialog
      class={["modal", @open? and "modal-open"]}
      data-testid={@testid}
      phx-key="escape"
      phx-target={assigns[:"phx-target"]}
      phx-window-keydown={@cancel}
    >
      <div
        :if={@open?}
        class={[
          "modal-box",
          "p-6 pr-3",
          @bg_class,
          !@full_height? and "max-h-[calc(100svh-4rem)]",
          @full_height? and "h-[calc(100svh-4rem)]",
          "mx-4",
          "overflow-hidden",
          "grid grid-rows-[auto_1fr]"
        ]}
        phx-click-away={@cancel}
        phx-mounted={JS.focus_first(to: "form")}
        phx-target={assigns[:"phx-target"]}
      >
        <div :if={@title != []} class="mb-2">
          {render_slot(@title)}
        </div>

        <div class="h-full overflow-y-auto pr-3">
          {render_slot(@inner_block)}
        </div>

        <.button_close
          :if={@cancel}
          cancel={@cancel}
          cancel_testid={@cancel_testid}
          phx-target={assigns[:"phx-target"]}
        />
      </div>
    </dialog>
    """
  end

  def button_close(assigns) do
    ~H"""
    <button
      phx-click={@cancel}
      phx-target={assigns[:"phx-target"]}
      data-testid={@cancel_testid}
      class={[
        "absolute right-2 top-2",
        "size-4 text-xs",
        "cursor-pointer",
        "opacity-50 hover:opacity-100 transition"
      ]}
    >
      ✕
    </button>
    """
  end
end
