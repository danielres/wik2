defmodule QblogWeb.Components.User do
  use QblogWeb, :html

  attr :link?, :boolean, default: false
  attr :tenant, :map, default: nil
  attr :user, :map, required: true

  def avatar(assigns) do
    ~H"""
    <div class="avatar avatar-placeholder">
      <div class="bg-neutral text-neutral-content size-8 rounded-full text-xs">
        <%= if @link? and @tenant != nil  do %>
          <.link
            navigate={profile_path(@tenant, @user)}
            class="opacity-80 hover:opacity-100 transition"
          >
            {initials(@user)}
          </.link>
        <% else %>
          {initials(@user)}
        <% end %>
      </div>
    </div>
    """
  end

  defp initials(user) do
    user
    |> to_string()
    |> String.slice(0, 2)
    |> String.upcase()
  end

  defp profile_path(tenant, user) do
    "/#{tenant.name}/wiki/members/#{user |> to_string()}"
  end
end
