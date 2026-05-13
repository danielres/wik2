defmodule WikWeb.Components.Block.Types.Members do
  use WikWeb, :html

  alias Wik.Accounts.GroupUserRelation
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
      Members block needs a group context.
    </div>

    <Cinder.collection
      :if={@query}
      id={"members-block-#{@block.id}"}
      page_size={[default: 25]}
      query={@query}
      query_opts={[load: [:avatar_url, :user]]}
      scope={@scope}
      show_filters={false}
      theme={WikWeb.Cinder.Themes.Dense}
      class={[
        "border-1 border-base-200/50 rounded-box",
        "shadow",
        "@sm/block:[&_th]:px-4 @sm/block:[&_th]:py-2",
        "@sm/block:[&_td]:px-4 @sm/block:[&_td]:py-2",
        "[&_tr]:hover:bg-base-100",
        "[&_th:first-child]:rounded-tl-md",
        "[&_th:last-child]:rounded-tr-md",
        "[&_th]:bg-base-200",
        "[&_table]:bg-white/80 dark:[&_table]:bg-base-300/20"
      ]}
      }
    >
      <:col :let={membership} label="" class="w-0">
        <Components.User.avatar
          link?
          membership={membership}
          size="md"
          tenant={@scope.tenant}
        />
      </:col>

      <:col :let={membership} field="user.email" label="Name" sort>
        {membership.user |> to_string()}
      </:col>

      <:col :let={membership} field="type" label="Role" sort>
        <span class={["badge badge-sm bg-base-200"]}>
          <span>{membership.type |> Atom.to_string() |> String.capitalize()}</span>

          <button
            :if={@actions? and Ash.can?({membership, :transfer_ownership}, @scope)}
            phx-click={@event_transfer_ownership_start}
            phx-value-membership_id={membership.id}
            class="opacity-50 hover:opacity-100 transition-opacity cursor-pointer"
          >
            <.icon name="hero-cog-micro" class="" />
          </button>

          <button
            :if={
              @actions? and membership.type != :owner and
                Ash.can?({membership, :update_membership_type}, @scope)
            }
            phx-click={@event_membership_type_change_start}
            phx-value-membership_id={membership.id}
            class="opacity-50 hover:opacity-100 transition-opacity cursor-pointer"
          >
            <.icon name="hero-cog-micro" class="" />
          </button>
        </span>
      </:col>

      <:col :let={membership} field="inserted_at" label="Joined" sort>
        <span
          class={[
            "badge badge-sm px-2 bg-base-200",
            "whitespace-nowrap",
            "tooltip tooltip-primary tooltip-left tooltip-delayed",
            "cursor-default"
          ]}
          data-tip={"Member since #{Utils.Time.precise(membership.inserted_at)}"}
        >
          {Utils.Time.relative(membership.inserted_at)}
        </span>
      </:col>
    </Cinder.collection>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true

  def form_fields(assigns) do
    ~H"""
    <div class="text-sm opacity-70">
      This block renders the current group members.
    </div>
    """
  end

  defp members_query(nil), do: nil
  defp members_query(%{tenant: nil}), do: nil

  defp members_query(%{tenant: %{id: group_id}}) do
    GroupUserRelation
    |> Ash.Query.filter(group_id == ^group_id)
    |> Ash.Query.sort(type_sort: :asc, inserted_at: :asc)
  end
end
