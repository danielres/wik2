defmodule WikWeb.Components.Presences do
  @moduledoc """
  Renders the list of online users for the current space.
  """
  alias WikWeb.Components
  use WikWeb, :html

  attr :presences, :list, default: []
  attr :tenant, :map, required: true

  def avatars(assigns) do
    ~H"""
    <div
      :for={presence <- @presences}
      id={"online-user-#{presence.id}"}
    >
      <Components.User.avatar
        link?={false}
        membership={Map.get(presence, :membership)}
        tenant={@tenant}
        size="sm"
        user={Map.get(presence, :user)}
      />
    </div>
    """
  end
end
