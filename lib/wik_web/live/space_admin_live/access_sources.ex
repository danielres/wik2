defmodule WikWeb.SpaceAdminLive.AccessSources do
  use WikWeb, :html

  alias WikWeb.Components.Membership.Access
  alias WikWeb.Components.Time
  alias WikWeb.Components.UI

  attr :groups, :list, required: true

  def render(assigns) do
    ~H"""
    <div
      id="space-admin-access-sources"
      class={[
        "space-y-3"
      ]}
    >
      <div :if={@groups == []} class="flex items-center gap-2" data-testid="access-sources-empty">
        <span class="text-sm opacity-70">No access sources yet.</span>
      </div>

      <div :if={@groups != []} class="space-y-2">
        <div
          :for={group <- @groups}
          id={"access-source-#{group.id}"}
          data-testid={"access-source-#{group.id}"}
        >
          <button
            type="button"
            phx-click={UI.modal_open("access-source-#{group.id}-modal")}
            class={[
              "text-left p-4",
              "w-full",
              "cursor-pointer",
              "rounded-box bg-base-300/50 hover:bg-base-200 transition"
            ]}
            aria-label="Open modal"
            title="Open modal"
          >
            <div>
              <div class="text-sm text-base-content/50">{group.type_label}</div>
              <div class="">{group.container_name}</div>
            </div>

            <div class="flex shrink-0 items-center gap-2 text-sm">
              <span>
                <.icon name="hero-user-micro" />
                <span class="badge badge-xs badge-neutral">{group.active_members_count}</span>
              </span>
              <span class="hidden opacity-60 sm:inline">active</span>
            </div>
          </button>

          <UI.modal id={"access-source-#{group.id}-modal"}>
            <div class="">
              <div :if={group.grants == []} class="text-sm opacity-60">
                No grants recorded for this source.
              </div>

              <div :if={group.grants != []} class="overflow-x-auto">
                <h3 class="mb-4">
                  <div class="text-sm text-base-content/50">{group.type_label}</div>
                  <div class="">{group.container_name}</div>
                </h3>
                <table class="table table-sm bg-base-200">
                  <thead>
                    <tr>
                      <th>Member</th>
                      <th>Grant</th>
                      <th>Source</th>
                      <th>Verified</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={grant <- group.grants} data-testid={"access-source-grant-#{grant.id}"}>
                      <td>
                        <div>{grant.member_label}</div>
                        <div>{grant.external_identity_label}</div>
                      </td>
                      <td>
                        <div class={grant_status_class(grant.grant_status)}>
                          {grant.grant_status}
                        </div>
                      </td>
                      <td>
                        <div class={source_status_class(grant.source_status)}>
                          {grant.source_status}
                        </div>
                      </td>
                      <td>
                        <Time.relative_and_precise datetime={grant.last_verified_at} />
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </UI.modal>
        </div>
      </div>
    </div>
    """
  end

  def prepare(sources) do
    Enum.map(sources, &prepare_source/1)
  end

  defp prepare_source(source) do
    grants =
      source.grants
      |> active_grants()
      |> sorted_grants()

    %{
      id: source.id,
      type_label: source_type_label(source),
      container_label: source_container_label(source),
      container_name: source_title(source),
      active_members_count: length(grants),
      grants: Enum.map(grants, &prepare_grant(&1, source))
    }
  end

  defp prepare_grant(grant, source) do
    %{
      id: grant.id,
      external_identity_label: Access.identity_label(grant.external_identity),
      grant_status: Atom.to_string(grant.status),
      inserted_at: grant.inserted_at,
      last_verified_at: grant.last_verified_at,
      member_label: member_label(grant, source),
      source_status: Atom.to_string(source.status)
    }
  end

  defp sorted_grants(grants) when is_list(grants) do
    Enum.sort_by(grants, & &1.last_verified_at, {:desc, DateTime})
  end

  defp sorted_grants(_grants), do: []

  defp active_grants(grants) when is_list(grants) do
    Enum.filter(grants, &(&1.status == :active))
  end

  defp active_grants(_grants), do: []

  defp member_label(%{user_id: user_id}, %{space: %{memberships: memberships}})
       when is_list(memberships) do
    memberships
    |> Enum.find(&(&1.user_id == user_id))
    |> case do
      %{username: username, type: type} when is_binary(username) and username != "" ->
        "#{username} (#{type})"

      %{user: %{email: email}, type: type} when is_binary(email) ->
        "#{email_username(email)} (#{type})"

      %{type: type} ->
        "Member (#{type})"

      nil ->
        fallback_user_label(user_id)
    end
  end

  defp member_label(%{user: %{email: email}}, _source) when is_binary(email),
    do: email_username(email)

  defp member_label(%{user_id: user_id}, _source), do: fallback_user_label(user_id)

  defp email_username(email) do
    email
    |> String.split("@")
    |> List.first()
  end

  defp fallback_user_label(user_id) when is_binary(user_id),
    do: "User #{String.slice(user_id, 0, 8)}"

  defp fallback_user_label(_user_id), do: "User"

  defp source_type_label(%{provider: :telegram, metadata: %{"chat" => %{"type" => "channel"}}}),
    do: "Telegram channel"

  defp source_type_label(%{provider: :telegram, metadata: %{"chat" => %{"type" => type}}})
       when type in ["group", "supergroup"],
       do: "Telegram group"

  defp source_type_label(%{provider: :telegram}), do: "Telegram group membership"
  defp source_type_label(%{provider: :google}), do: "Google account"
  defp source_type_label(%{provider: provider}), do: provider |> Atom.to_string()

  defp source_container_label(%{
         provider: :telegram,
         metadata: %{"chat" => %{"type" => "channel"}}
       }),
       do: "Channel"

  defp source_container_label(%{provider: :google}), do: "Account"
  defp source_container_label(_source), do: "Group"

  defp source_title(%{provider: :google}), do: "Google account"

  defp source_title(%{title: title}) when is_binary(title) and title != "", do: title

  defp source_title(%{metadata: %{"chat" => %{"title" => title}}}) when is_binary(title),
    do: title

  defp source_title(_source), do: "Unknown source"

  defp grant_status_class("active"), do: "badge badge-sm badge-success"
  defp grant_status_class(_status), do: "badge badge-sm badge-neutral"

  defp source_status_class("active"), do: "badge badge-sm badge-success"
  defp source_status_class(_status), do: "badge badge-sm badge-neutral"
end
