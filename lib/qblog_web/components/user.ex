defmodule QblogWeb.Components.User do
  use QblogWeb, :html

  attr :avatar_url, :string, default: nil
  attr :link?, :boolean, default: false
  attr :size, :string, default: "md"
  attr :tenant, :map, default: nil
  attr :tooltip?, :boolean, default: false
  attr :tooltip_direction, :string, default: "left"
  attr :tooltip_variant_class, :string, default: ""
  attr :user, :map, default: nil

  def avatar(assigns) do
    size_class =
      case assigns.size do
        "xs" -> "size-4 text-[0.6rem]"
        "sm" -> "size-6 text-[0.7rem]"
        "md" -> "size-8"
        _ -> "size-8"
      end

    profile_path =
      if assigns.tenant != nil and assigns.link? do
        profile_path(assigns.tenant, assigns.user)
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
      |> assign(tooltip_direction_class: tooltip_direction_class)
      |> assign(profile_path: profile_path)
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
        @avatar_url == nil && "avatar-placeholder"
      ]}>
        <div class={[
          "rounded-full",
          @avatar_url && "overflow-hidden",
          @avatar_url == nil && "bg-base-300 text-xs grid place-items-center",
          @size_class
        ]}>
          <.link
            :if={@profile_path}
            navigate={@profile_path}
            class={[
              "size-full grid place-items-center",
              "opacity-80 hover:opacity-100 transition"
            ]}
          >
            <.avatar_content avatar_url={@avatar_url} tenant={@tenant} user={@user} />
          </.link>

          <.avatar_content
            :if={@profile_path == nil}
            avatar_url={@avatar_url}
            tenant={@tenant}
            user={@user}
          />
        </div>
      </div>

      <div :if={@tooltip?} class="tooltip-content text-xs">
        {@user |> to_string()}
      </div>
    </div>
    """
  end

  attr :avatar_url, :string, default: nil
  attr :tenant, :map, default: nil
  attr :user, :map, default: nil

  defp avatar_content(assigns) do
    ~H"""
    <img :if={@avatar_url} src={@avatar_url} class="size-full object-cover" />
    <.icon :if={@avatar_url == nil and @tenant == nil} name="hero-user" class="size-1/2" />
    <span :if={@avatar_url == nil and @tenant != nil}>{initials(@user)}</span>
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
