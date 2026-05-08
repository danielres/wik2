defmodule WikWeb.Components.Modal do
  use Phoenix.Component

  alias Phoenix.LiveView.JS
  alias WikWeb.Components.UI

  attr :"phx-target", :any, required: false
  attr :bg_class, :string, default: "bg-base-100"
  attr :cancel, :string, default: nil
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
        <h3 class="mb-2">
          {render_slot(@title)}
        </h3>

        <div class="h-full overflow-y-auto pr-3">
          {render_slot(@inner_block)}
        </div>

        <UI.modal_button_close
          :if={@cancel}
          phx-click={@cancel}
          data-testid={@cancel_testid}
          phx-target={assigns[:"phx-target"]}
        />
      </div>
    </dialog>
    """
  end
end
