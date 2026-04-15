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
        <div class="card bg-base-200">
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
    <ul class="menu bg-base-200 rounded-box w-full p-2">
      <li>
        <.link
          :for={group <- @groups}
          class="justify-between"
          navigate={~p"/#{group.name}/wiki"}
        >
          {group.name}
          <span class="font-thin">{group.author |> to_string}</span>
        </.link>

        <span :if={@groups == []} class="opacity-70">
          You are not a member of any groups yet.
        </span>
      </li>
    </ul>
    """
  end

  attr :scope, :any, required: true
  attr :event_transfer_ownership_start, :string, required: true
  attr :memberships, :list, required: true

  def memberships(assigns) do
    ~H"""
    <ul class="space-y-0.5">
      <li
        :for={membership <- @memberships}
        class={[
          "flex items-center justify-between gap-1 flex-wrap",
          "rounded bg-base-100/50 px-3 py-2"
        ]}
      >
        <span>{membership.user |> to_string()}</span>

        <span class={[
          "flex flex-wrap gap-1",
          "text-sm opacity-70"
        ]}>
          <span class={["badge badge-sm px-2 bg-base-300"]}>
            <button
              :if={Ash.can?({membership, :transfer_ownership}, @scope)}
              phx-click={@event_transfer_ownership_start}
              phx-value-membership_id={membership.id}
              class="opacity-50 hover:opacity-100 transition-opacity cursor-pointer"
            >
              <.icon name="hero-cog-micro" class="" />
            </button>
            {membership.type |> Atom.to_string() |> String.capitalize()}
          </span>

          <span class={["badge badge-sm px-2 bg-base-300", "whitespace-nowrap"]}>
            Since {Calendar.strftime(membership.inserted_at, "%Y-%m-%d %H:%M")}
          </span>
        </span>
      </li>
    </ul>
    """
  end
end
