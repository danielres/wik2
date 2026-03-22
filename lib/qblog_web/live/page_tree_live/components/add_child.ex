defmodule QblogWeb.PageTreeLive.Components.AddChild do
  import QblogWeb.CoreComponents
  use Phoenix.Component

  attr :form, :any, required: true
  attr :nodes_flat, :list, required: true
  attr :parent_id, :integer, default: nil
  attr :scope, :map, required: true
  attr :target, :any, required: true

  def dialog(assigns) do
    assigns =
      assigns
      |> assign(
        parent_node: assigns.nodes_flat |> Enum.find(fn node -> node.id == assigns.parent_id end)
      )

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
            <%= if (@parent_node) do %>
              Add under <span class="font-bold">{@parent_node.slug}</span>
            <% else %>
              Add at top level
            <% end %>
          </.button>
        </div>
      </div>
    </.form>
    """
  end
end
