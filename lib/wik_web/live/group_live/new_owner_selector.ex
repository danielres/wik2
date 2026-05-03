defmodule WikWeb.GroupLive.NewOwnerSelector do
  use WikWeb, :html

  attr :event_transfer_ownership, :string, required: true
  attr :memberships, :list, required: true

  def render(assigns) do
    non_owners = assigns.memberships |> Enum.filter(&(&1.type != :owner))
    assigns = assigns |> assign(non_owners: non_owners)

    ~H"""
    <div class="alert bg-error/50 text-error-content mb-4">
      <.icon name="hero-exclamation-circle-micro self-start" class="size-6 opacity-50" />

      <div class="leading-tight space-y-2">
        <p class="font-bold">This action will transfer ownership to the selected member.</p>
        <p>
          You will become administrator of the group, and won't be able to transfer ownership again unless the new owner transfers it back to you.
        </p>
      </div>
    </div>

    <h3 class="text-xl mb-2">Select new owner</h3>

    <ul class="space-y-0.5">
      <li :if={@non_owners == []} class="text-sm opacity-70 italic">
        No other members in the group to transfer ownership to.
      </li>

      <li :for={membership <- @non_owners}>
        <button
          class={[
            "w-full",
            "opacity-80 hover:opacity-100 transition-all cursor-pointer",
            "flex items-center justify-between gap-1 flex-wrap",
            "rounded bg-base-300 hover:bg-info/20 px-3 py-2"
          ]}
          phx-click={@event_transfer_ownership}
          phx-value-target_membership_id={membership.id}
        >
          <span>{membership.user |> to_string()}</span>

          <span class={[
            "flex flex-wrap gap-1",
            "text-sm opacity-70"
          ]}>
            <span class={["badge badge-sm px-2 bg-base-300"]}>
              {membership.type |> Atom.to_string() |> String.capitalize()}
            </span>
          </span>
        </button>
      </li>
    </ul>
    """
  end
end
