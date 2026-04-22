defmodule QblogWeb.Components.User do
  use QblogWeb, :html

  attr :link?, :boolean, default: false
  attr :tenant, :map, default: nil
  attr :user, :map, default: nil
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
        "bg-base-300 rounded-full text-xs",
        "grid place-items-center",
        @size_class
      ]}>
        <.icon :if={@tenant == nil} name="hero-user" class="size-1/2" />

        <%= if @tenant != nil and @link? do %>
          <.link
            navigate={profile_path(@tenant, @user)}
            class="opacity-80 hover:opacity-100 transition"
          >
            {initials(@user)}
          </.link>
        <% end %>

        <%= if @tenant != nil and not @link? do %>
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
