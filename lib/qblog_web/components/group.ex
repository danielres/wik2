defmodule QblogWeb.Components.Group do
  use Phoenix.Component
  use QblogWeb, :live_view

  attr :form, :any, required: true
  attr :class, :string, default: ""
  attr :action_type, :string, default: "create"

  def form(assigns) do
    ~H"""
    <div class={[@class]}>
      <Phoenix.Component.form
        for={@form}
        phx-change="validate"
        phx-submit="submit"
      >
        <div class="card bg-base-300">
          <div class="card-body">
            <.input field={@form[:name]} label="Name" />
            <.input field={@form[:description]} label="Description" type="textarea" />

            <.button type="submit" class="btn btn-primary mt-3">
              {@action_type |> String.capitalize()} group
            </.button>
          </div>
        </div>
      </Phoenix.Component.form>
    </div>
    """
  end

  attr :groups, :list, required: true

  def list(assigns) do
    ~H"""
    <.link
      :for={group <- @groups}
      class="btn btn-soft justify-between"
      navigate={~p"/#{group.name}"}
    >
      {group.name}
      <span class="font-thin">{group.author |> to_string}</span>
    </.link>

    <span :if={@groups == []} class="opacity-70">
      You are not a member of any groups yet.
    </span>
    """
  end
end
