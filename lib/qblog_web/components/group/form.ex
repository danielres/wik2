defmodule QblogWeb.Components.Group.Form do
  use Phoenix.Component

  alias Qblog.Accounts.Group
  alias QblogWeb.CoreComponents

  attr :form, :any, required: true
  attr :class, :string, default: ""
  attr :action_type, :string, default: "create"

  def render(assigns) do
    ~H"""
    <div class={[@class]}>
      <.form
        for={@form}
        phx-change="validate"
        phx-submit="submit"
      >
        <div class="card bg-base-300">
          <div class="card-body">
            <CoreComponents.input field={@form[:name]} label="Name" />
            <CoreComponents.input field={@form[:description]} label="Description" type="textarea" />

            <CoreComponents.button type="submit" class="btn btn-primary mt-3">
              {@action_type |> String.capitalize()} group
            </CoreComponents.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
