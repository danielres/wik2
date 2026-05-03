defmodule WikWeb.Components.Block.Types.Embed do
  use WikWeb, :html

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    supported = Wik.Blocks.Types.Embed.available() |> Enum.map(& &1.label)
    assigns = assign(assigns, supported: supported)

    ~H"""
    <div class="flex flex-wrap gap-2 items-center">
      <div class="font-bold">Supported:</div>
      <ul class="flex flex-wrap gap-2">
        <li :for={type <- @supported} class="badge">
          {type}
        </li>
      </ul>
    </div>

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
    # "border-2 border-base-200 rounded-box"
    ~H"""
    <div class={[
      "ring-1 ring-base-200/50",
      "rounded-box [&>*]:rounded-lg",
      "shadow"
    ]}>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
