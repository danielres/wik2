defmodule WikWeb.Components.Block.Types.Members do
  use WikWeb, :html

  alias Wik.Accounts.Membership
  alias WikWeb.Components

  require Ash.Query

  attr :block, :map, required: true
  attr :event_membership_type_change_start, :string, default: nil
  attr :event_transfer_ownership_start, :string, default: nil
  attr :actions?, :boolean, default: false
  attr :scope, :map, default: nil

  def render(assigns) do
    assigns =
      assigns
      |> assign(:query, members_query(assigns.scope))

    ~H"""
    <div :if={@query == nil} class="text-sm opacity-60">
      Members block needs a space context.
    </div>

    <Cinder.collection
      :if={@query}
      id={"members-block-#{@block.id}"}
      layout={:list}
      page_size={[default: 10]}
      query={@query}
      query_opts={[load: [:avatar_url, :space, :user]]}
      scope={@scope}
      show_filters={false}
      theme={WikWeb.Cinder.Themes.Dense}
      class={[
        "@sm/block:[&_th]:px-4 @sm/block:[&_th]:py-2",
        "@sm/block:[&_td]:px-4 @sm/block:[&_td]:py-2"
      ]}
      }
    >
      <:item :let={membership}>
        <div class={[
          "bg-base-300/30 rounded-lg p-2 stacked",
          !@actions? and "hover:bg-base-300/50",
          (@actions? and membership.type == :owner and
             Ash.can?({membership, :transfer_ownership}, @scope)) &&
            "border border-accent/50 hover:border-accent",
          (@actions? and membership.type != :owner and
             Ash.can?({membership, :update_membership_type}, @scope)) &&
            "border border-accent/50 hover:border-accent"
        ]}>
          <.link
            :if={!@actions?}
            navigate={Components.User.membership_profile_path(membership)}
            class="flex justify-between"
          >
            <.member_row_content membership={membership} />
          </.link>

          <div :if={@actions?} class="flex justify-between">
            <.member_row_content membership={membership} />
          </div>

          <button
            :if={
              @actions? and membership.type != :owner and
                Ash.can?({membership, :update_membership_type}, @scope)
            }
            phx-click={@event_membership_type_change_start}
            phx-value-membership_id={membership.id}
            class="opacity-50 hover:opacity-100 transition-opacity cursor-pointer"
          >
          </button>

          <button
            :if={@actions? and Ash.can?({membership, :transfer_ownership}, @scope)}
            phx-click={@event_transfer_ownership_start}
            phx-value-membership_id={membership.id}
            class="opacity-50 hover:opacity-100 transition-opacity cursor-pointer"
          >
          </button>
        </div>
      </:item>

      <:col :if={false} field="user.email" label="Username" sort></:col>
      <:col :if={false} field="type" label="Role" sort></:col>
      <:col :if={false} field="inserted_at" label="Joined" sort></:col>
    </Cinder.collection>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    ~H"""
    <div class="text-sm opacity-70">
      This block renders the current space members.
    </div>
    """
  end

  attr :membership, :map, required: true

  defp member_row_content(assigns) do
    ~H"""
    <Components.User.identity
      avatar_size="lg"
      class="gap-2 text-xs"
      membership={@membership}
    />

    <div class="text-end">
      <div>
        <span class={["badge badge-sm bg-base-300 text-xs text"]}>
          <span>{@membership.type |> Atom.to_string() |> String.capitalize()}</span>
        </span>
      </div>
      <div>
        <span
          class={[
            "badge badge-sm px-2 bg-base-200",
            "whitespace-nowrap",
            "tooltip tooltip-left tooltip-delayed",
            "cursor-default",
            "text-base-content/40"
          ]}
          data-tip={"Member since #{Utils.Time.precise(@membership.inserted_at)}"}
        >
          {Utils.Time.relative(@membership.inserted_at)}
        </span>
      </div>
    </div>
    """
  end

  defp members_query(nil), do: nil
  defp members_query(%{tenant: nil}), do: nil

  defp members_query(%{tenant: %{id: space_id}}) do
    Membership
    |> Ash.Query.filter(space_id == ^space_id)
    |> Ash.Query.sort(type_sort: :asc, inserted_at: :asc)
  end
end
