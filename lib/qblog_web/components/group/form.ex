defmodule QblogWeb.Components.Group.Form do
  use Phoenix.Component

  alias Qblog.Accounts.Group
  alias QblogWeb.CoreComponents

  attr :form, :any, required: true
  attr :fields, :list, required: true
  attr :class, :string, default: ""

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
            <CoreComponents.input
              :for={field <- @fields}
              type={Group.field_type_for(field)}
              field={@form[field]}
              label={field |> Phoenix.Naming.humanize()}
            />
            <CoreComponents.button type="submit" class="btn btn-primary mt-3">
              Create group
            </CoreComponents.button>
          </div>
        </div>
      </.form>
    </div>
    """
  end
end
