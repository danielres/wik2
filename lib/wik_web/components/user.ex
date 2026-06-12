defmodule WikWeb.Components.User do
  use WikWeb, :html

  alias Wik.Accounts
  alias WikWeb.GoogleAvatarCache

  attr :avatar_url, :string, default: nil
  attr :membership, :map, default: nil
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
      |> assign(
        :resolved_avatar_url,
        assigns |> resolved_avatar_url() |> GoogleAvatarCache.cached_url()
      )
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
          <.avatar_content
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

  attr :avatar_size, :string, default: "xs"
  attr :class, :string, default: nil
  attr :link?, :boolean, default: false
  attr :membership, :map, required: true
  attr :name?, :boolean, default: true
  attr :testid, :string, default: nil
  attr :tooltip?, :boolean, default: false
  attr :tooltip_direction, :string, default: "left"

  def identity(assigns) do
    membership = normalize_identity_membership(assigns.membership)

    assigns =
      assigns
      |> assign(:membership, membership)
      |> assign(
        :profile_path,
        if(assigns.link?, do: membership_profile_path(membership))
      )

    ~H"""
    <.link
      :if={@profile_path}
      navigate={@profile_path}
      class={[
        "flex items-center gap-1 truncate opacity-80 hover:opacity-100 transition",
        @class
      ]}
      data-testid={@testid}
    >
      <.avatar
        membership={@membership}
        size={@avatar_size}
        tooltip?={@tooltip?}
        tooltip_direction={@tooltip_direction}
      />
      <span :if={@name?}>{@membership.display_name}</span>
    </.link>

    <div
      :if={@profile_path in [nil, ""]}
      class={[
        "flex items-center gap-1 truncate",
        @class
      ]}
      data-testid={@testid}
    >
      <.avatar
        membership={@membership}
        size={@avatar_size}
        tooltip?={@tooltip?}
        tooltip_direction={@tooltip_direction}
      />
      <span :if={@name?}>{@membership.display_name}</span>
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

  def membership_profile_path(%{space: %{slug: tenant_slug}} = membership) do
    case Map.get(membership, :username) do
      username when is_binary(username) and username != "" ->
        "/#{tenant_slug}/wiki/members/#{username}"

      _username ->
        nil
    end
  end

  def membership_profile_path(_membership), do: nil

  defp resolved_user(%{membership: membership}) when not is_nil(membership) do
    Map.get(membership, :user)
  end

  defp resolved_user(assigns), do: assigns.user

  defp resolved_username(%{membership: membership}) when not is_nil(membership) do
    Map.get(membership, :username)
  end

  defp resolved_username(assigns), do: assigns.username

  defp normalize_identity_membership(%{display_name: _display_name} = membership), do: membership
  defp normalize_identity_membership(membership), do: Accounts.present_membership(membership)
end
