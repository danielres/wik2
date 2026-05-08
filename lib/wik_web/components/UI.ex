defmodule WikWeb.Components.UI do
  use WikWeb, :html

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
