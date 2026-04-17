defmodule QblogWeb.Components.User do
  use QblogWeb, :html

  attr :link?, :boolean, default: false
  attr :tenant, :map, default: nil
  attr :user, :map, required: true
  attr :size, :string, default: "md"

  def avatar(assigns) do
    size_class =
      case assigns.size do
        "xs" -> "size-4 text-[0.6rem]"
        "sm" -> "size-6 text-[0.7rem]"
        "md" -> "size-8"
        _ -> "size-8"
      end

    assigns = assigns |> assign(size_class: size_class)

    ~H"""
    <div class="avatar avatar-placeholder">
      <div class={[
        "bg-neutral text-neutral-content rounded-full text-xs",
        @size_class
      ]}>
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
