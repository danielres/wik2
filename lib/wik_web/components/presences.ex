defmodule WikWeb.Components.Presences do
  @moduledoc """
  Renders the list of online users for the current group.
  """
  alias WikWeb.Components
  use WikWeb, :html

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
          link?
          membership={presence.membership}
          tenant={@tenant}
          size="sm"
        />
      </li>
    </ul>
    """
  end
end
