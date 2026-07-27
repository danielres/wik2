defmodule WikWeb.PageLive.Components.LinkedCopy do
  use WikWeb, :html

  attr :linked_copy_form, :map, required: true
  attr :linked_copy_error, :string, required: true
  attr :rest, :global, include: ~w(class id phx-submit)

  def form(assigns) do
    ~H"""
    <Phoenix.Component.form
      for={@linked_copy_form}
      {@rest}
    >
      <.input field={@linked_copy_form[:block_id]} label="Block ID" phx-mounted={JS.focus()} />
      <input
        name={@linked_copy_form[:position].name}
        type="hidden"
        value={@linked_copy_form[:position].value}
      />

      <div :if={@linked_copy_error} class="text-error text-sm">{@linked_copy_error}</div>

      <div class="flex justify-end gap-2">
        <.button
          class="btn btn-ghost btn-sm"
          phx-click="linked_copy:cancel"
          type="button"
        >
          Cancel
        </.button>
        <.button class="btn btn-primary btn-sm" type="submit">Link block</.button>
      </div>
    </Phoenix.Component.form>
    """
  end
end
