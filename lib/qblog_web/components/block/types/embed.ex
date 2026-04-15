defmodule QblogWeb.Components.Block.Types.Embed do
  use QblogWeb, :html

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    supported = Qblog.Blocks.Types.Embed.available() |> Enum.map(& &1.label)
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
end
