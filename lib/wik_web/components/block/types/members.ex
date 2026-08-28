defmodule WikWeb.Components.Block.Types.Members do
  use WikWeb, :html

  alias Wik.Accounts.Membership
  alias WikWeb.Components
  alias WikWeb.Components.UI

  require Ash.Query

  attr :block, :map, required: true
  attr :event_membership_type_change_start, :string, default: nil
  attr :event_transfer_ownership_start, :string, default: nil
  attr :actions?, :boolean, default: false
  attr :scope, :map, default: nil
  attr :user_tz, :string, default: "Etc/UTC"

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
    >
      <:item :let={membership}>
        <% edit_action =
          member_edit_action(
            membership,
            @actions?,
            @scope,
            @event_membership_type_change_start,
            @event_transfer_ownership_start
          ) %>

        <UI.editable_zone
          editing?={edit_action != nil}
          phx-click={edit_action && edit_action.event}
          phx-value-membership_id={membership.id}
          title={if(edit_action, do: edit_action.title, else: "Edit membership")}
        >
          <div class={[
            "bg-base-300/30 rounded-lg p-2",
            !@actions? and "hover:bg-base-300/50"
          ]}>
            <.member_row actions?={@actions?} membership={membership} user_tz={@user_tz} />
          </div>
        </UI.editable_zone>
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

  attr :actions?, :boolean, required: true
  attr :user_tz, :string, required: true

  defp member_row(assigns) do
    assigns =
      assign(assigns, :profile_path, Components.User.membership_profile_path(assigns.membership))

    ~H"""
    <.link
      :if={!@actions? and @profile_path}
      navigate={@profile_path}
      class="flex justify-between"
    >
      <.member_row_content membership={@membership} user_tz={@user_tz} />
    </.link>

    <div :if={@actions? or @profile_path in [nil, ""]} class="flex justify-between">
      <.member_row_content membership={@membership} user_tz={@user_tz} />
    </div>
    """
  end

  attr :membership, :map, required: true
  attr :user_tz, :string, required: true

  defp member_row_content(assigns) do
    ~H"""
    <Components.User.identity
      avatar_size="lg"
      class="gap-2 text-xs"
      membership={@membership}
    />

    <div class="text-end">
      <div>
        <span
          class={["badge badge-sm bg-base-300 text-xs text"]}
          data-testid={"member-row-role-#{@membership.id}"}
        >
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
          data-tip={member_since_tooltip(@membership.inserted_at, @user_tz)}
        >
          Member since: {Utils.Time.relative(@membership.inserted_at)}
        </span>

        <span
          class={[
            "badge badge-sm px-2 bg-base-200",
            "whitespace-nowrap",
            "tooltip tooltip-left tooltip-delayed",
            "cursor-default",
            "text-base-content/40"
          ]}
          data-testid={"member-row-last-seen-#{@membership.id}"}
          data-tip={last_seen_tooltip(@membership.last_seen_at, @user_tz)}
        >
          Last seen: {last_seen_text(@membership.last_seen_at)}
        </span>
      </div>
    </div>
    """
  end

  defp member_edit_action(_membership, false, _scope, _membership_type_event, _transfer_event),
    do: nil

  defp member_edit_action(membership, true, scope, membership_type_event, transfer_event) do
    cond do
      actionable_event?(transfer_event) and transfer_ownership_available?(membership, scope) ->
        %{event: transfer_event, title: "Transfer ownership"}

      actionable_event?(membership_type_event) and membership.type != :owner ->
        %{event: membership_type_event, title: "Change membership type"}

      true ->
        nil
    end
  end

  defp actionable_event?(event), do: is_binary(event) and event != ""

  defp transfer_ownership_available?(%{type: :owner}, %{actor: %{role: :superadmin}}),
    do: true

  defp transfer_ownership_available?(
         %{type: :owner, user_id: user_id},
         %{actor: %{id: user_id}}
       ),
       do: true

  defp transfer_ownership_available?(_membership, _scope), do: false

  defp member_since_tooltip(inserted_at, user_tz) do
    precise_inserted_at =
      inserted_at
      |> Utils.Tz.to_local!(user_tz)
      |> Utils.Time.precise()

    "Member since #{precise_inserted_at}"
  end

  defp last_seen_text(nil), do: "never"
  defp last_seen_text(last_seen_at), do: relative_time_ago(last_seen_at)

  defp last_seen_tooltip(nil, _user_tz), do: "This member has not connected to this space yet"

  defp last_seen_tooltip(last_seen_at, user_tz) do
    precise_last_seen =
      last_seen_at
      |> Utils.Tz.to_local!(user_tz)
      |> Utils.Time.precise()

    "Last seen #{precise_last_seen}"
  end

  defp relative_time_ago(datetime) do
    case Utils.Time.relative(datetime) do
      "just now" -> "just now"
      relative -> "#{relative} ago"
    end
  end

  defp members_query(nil), do: nil
  defp members_query(%{tenant: nil}), do: nil

  defp members_query(%{tenant: %{id: space_id}}) do
    Membership
    |> Ash.Query.filter(space_id == ^space_id)
    |> Ash.Query.sort(type_sort: :asc, inserted_at: :asc)
  end
end
