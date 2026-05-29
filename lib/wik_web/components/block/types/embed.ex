defmodule WikWeb.Components.Block.Types.Embed do
  use WikWeb, :html

  alias WikWeb.Components.UI

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    ~H"""
    <.input
      field={@form[:url]}
      id={"edit-block-url-#{@block.id}"}
      label="Embed URL or iframe code"
      phx-mounted={JS.focus()}
      type="textarea"
    />
    """
  end

  def wrapper(assigns) do
    # generate random id:
    id = "embed-#{:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false)}"
    assigns = assign(assigns, :id, id)

    ~H"""
    <div>
      <div class="relative">
        <div class={[
          "absolute -top-6 right-0",
          "hidden max-sm:flex"
        ]}>
          <button
            type="button"
            phx-click={UI.modal_open(@id)}
            class="ml-auto cursor-pointer opacity-30 hover:opacity-100"
            aria-label="Open fullscreen"
            title="Open fullscreen"
          >
            <.icon name="hero-arrows-pointing-out-micro" class="opacity-50" />
          </button>
        </div>
      </div>

      <UI.modal id={@id} full?>
        <div class={[
          "min-h-[calc(100svh-3rem)]",
          "[&_iframe]:min-h-[calc(100svh-3rem)]"
        ]}>
          {render_slot(@inner_block)}
        </div>
      </UI.modal>

      <div class={[
        "ring-1 ring-base-200/50",
        "rounded-box [&>*]:rounded-lg",
        "shadow",
        "min-h-[50ch]",
        "[&_iframe]:min-h-[50ch]",
        "[&_iframe]:h-full",
        "sm:resize-y sm:overflow-y-auto"
      ]}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
