defmodule QblogWeb.PageTreeLive.Components.AddChild do
  import QblogWeb.CoreComponents
  use Phoenix.Component

  attr :form, :any, required: true
  attr :parent_id, :map, default: nil
  attr :target, :any, required: true

  def dialog(assigns) do
    ~H"""
    <.form
      for={@form}
      phx-change="validate_child"
      phx-submit="add_child"
      phx-target={@target}
    >
      <div class="card bg-base-100">
        <div class="card-body [&_input]:bg-base-200">
          <.input
            field={@form[:parent_id]}
            type="hidden"
            value={@parent_id}
          />
          <.input
            field={@form[:slug]}
            label="slug"
          />
          <.button
            class="btn btn-primary"
            type="submit"
          >
            Add
          </.button>
        </div>
      </div>
    </.form>
    """
  end
end
