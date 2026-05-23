defmodule WikWeb.Components.User do
  use WikWeb, :html

  attr :avatar_url, :string, default: nil
  attr :link?, :boolean, default: false
  attr :membership, :map, default: nil
  attr :profile_path, :string, default: nil
  attr :size, :string, default: "md"
  attr :tenant, :map, default: nil
  attr :tooltip?, :boolean, default: false
  attr :tooltip_direction, :string, default: "left"
  attr :tooltip_variant_class, :string, default: ""
  attr :username, :string, default: nil
  attr :user, :map, default: nil

  def avatar(assigns) do
    size_class =
      case assigns.size do
        "xs" -> "size-4 text-[0.6rem]"
        "sm" -> "size-6 text-[0.7rem]"
        "md" -> "size-8"
        "lg" -> "size-10"
        "xl" -> "size-12"
        _ -> "size-8"
      end

    tooltip_direction_class =
      case assigns[:tooltip_direction] do
        "left" -> "tooltip-left"
        "right" -> "tooltip-right"
        "top" -> "tooltip-top"
        "bottom" -> "tooltip-bottom"
        _ -> "tooltip-left"
      end

    assigns =
      assigns
      |> assign(:resolved_avatar_url, resolved_avatar_url(assigns))
      |> assign(:resolved_profile_path, resolved_profile_path(assigns))
      |> assign(:resolved_user, resolved_user(assigns))
      |> assign(:resolved_username, resolved_username(assigns))
      |> assign(tooltip_direction_class: tooltip_direction_class)
      |> assign(size_class: size_class)

    ~H"""
    <div
      class={[
        @tooltip? and "tooltip tooltip-delayed tooltip-xs",
        @tooltip_direction_class,
        @tooltip_variant_class
      ]}
      style="--tt-off: calc(100% + 0.1rem);"
    >
      <div class={[
        "avatar",
        @resolved_avatar_url == nil && "avatar-placeholder"
      ]}>
        <div class={[
          "rounded-full",
          @resolved_avatar_url && "overflow-hidden",
          @resolved_avatar_url == nil && "bg-base-300 text-xs grid place-items-center",
          @size_class
        ]}>
          <.link
            :if={@link? and @resolved_profile_path != nil}
            navigate={@resolved_profile_path}
            class={[
              "size-full grid place-items-center",
              "opacity-80 hover:opacity-100 transition"
            ]}
          >
            <.avatar_content
              avatar_url={@resolved_avatar_url}
              tenant={@tenant}
              username={@resolved_username}
              user={@resolved_user}
            />
          </.link>

          <.avatar_content
            :if={not (@link? and @resolved_profile_path != nil)}
            avatar_url={@resolved_avatar_url}
            tenant={@tenant}
            username={@resolved_username}
            user={@resolved_user}
          />
        </div>
      </div>

      <div :if={@tooltip?} class="tooltip-content text-xs">
        {@resolved_user |> to_string()}
      </div>
    </div>
    """
  end

  attr :avatar_url, :string, default: nil
  attr :tenant, :map, default: nil
  attr :username, :string, default: nil
  attr :user, :map, default: nil

  defp avatar_content(assigns) do
    initials = initials(assigns.username, assigns.user)
    show_icon? = is_nil(assigns.avatar_url) and (is_nil(assigns.tenant) or initials == nil)

    assigns =
      assigns
      |> assign(:initials, initials)
      |> assign(:show_icon?, show_icon?)

    ~H"""
    <img :if={@avatar_url} src={@avatar_url} class="size-full object-cover" />
    <.icon :if={@show_icon?} name="hero-user" class="size-1/2" />
    <span :if={@avatar_url == nil and @tenant != nil and @initials != nil}>{@initials}</span>
    """
  end

  defp initials(username, _user) when is_binary(username) and username != "" do
    username
    |> String.slice(0, 2)
    |> String.upcase()
    |> case do
      "" -> nil
      initials -> initials
    end
  end

  defp initials(_username, nil), do: nil

  defp initials(_username, user) do
    user
    |> to_string()
    |> String.slice(0, 2)
    |> String.upcase()
    |> case do
      "" -> nil
      initials -> initials
    end
  end

  defp resolved_avatar_url(%{membership: membership}) when not is_nil(membership) do
    Map.get(membership, :avatar_url)
  end

  defp resolved_avatar_url(assigns), do: assigns.avatar_url

  def resolved_profile_path(%{profile_path: profile_path}) when is_binary(profile_path),
    do: profile_path

  def resolved_profile_path(%{membership: membership, tenant: %{slug: tenant_slug}})
      when not is_nil(membership) do
    case Map.get(membership, :username) do
      username when is_binary(username) and username != "" ->
        "/#{tenant_slug}/wiki/members/#{username}"

      _username ->
        nil
    end
  end

  def resolved_profile_path(_assigns), do: nil

  defp resolved_user(%{membership: membership}) when not is_nil(membership) do
    Map.get(membership, :user)
  end

  defp resolved_user(assigns), do: assigns.user

  defp resolved_username(%{membership: membership}) when not is_nil(membership) do
    Map.get(membership, :username)
  end

  defp resolved_username(assigns), do: assigns.username
end
