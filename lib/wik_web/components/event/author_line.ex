defmodule WikWeb.Components.Event.AuthorLine do
  use WikWeb, :html

  alias WikWeb.Components.User

  attr :avatar_url, :string, default: nil
  attr :display_name, :string, required: true
  attr :tenant, :map, required: true
  attr :testid, :string, default: nil
  attr :user, :map, required: true

  def render(assigns) do
    ~H"""
    <div
      :if={@display_name not in [nil, ""]}
      class="truncate text-xs opacity-60 flex items-center gap-1"
      data-testid={@testid}
    >
      <User.avatar
        avatar_url={@avatar_url}
        size="xs"
        tenant={@tenant}
        user={@user}
      />
      {@display_name}
    </div>
    """
  end
end
