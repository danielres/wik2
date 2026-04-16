defmodule QblogWeb.Components.Presences do
  @moduledoc """
  Renders the list of online users for the current group.
  """
  alias QblogWeb.Components
  use QblogWeb, :html

  attr :presences, :list, default: []
  attr :tenant, :map, required: true

  def avatars(assigns) do
    ~H"""
    <ul class="avatar-group -space-x-0">
      <li
        :for={presence <- @presences}
        id={"online-user-#{presence.id}"}
      >
        <Components.User.avatar
          user={presence.user}
          href={profile_path(@tenant, presence.user)}
        />
      </li>
    </ul>
    """
  end

  defp profile_path(tenant, user) do
    "/#{tenant.name}/wiki/members/#{user |> to_string()}"
  end
end
