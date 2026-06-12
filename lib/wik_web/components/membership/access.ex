defmodule WikWeb.Components.Membership.Access do
  use WikWeb, :html

  alias WikWeb.Components.Time
  alias WikWeb.GoogleAvatarCache

  attr :current_user, :map, default: nil
  attr :grant, :map, required: true
  attr :variant, :atom, default: :me

  def grant_card(assigns) do
    issuer_membership = issuer_membership(assigns.grant)

    assigns =
      assigns
      |> assign(:issuer_label, issuer_label(assigns.grant, issuer_membership))
      |> assign(:issuer_membership, issuer_membership)
      |> assign(:membership, grant_membership(assigns.grant, assigns.current_user))
      |> assign(:source_type_label, source_type_label(assigns.grant.source))

    ~H"""
    <div class="card bg-base-300" data-testid={"access-grant-#{@grant.id}"}>
      <div class="card-body gap-3 py-4">
        <%= if @variant == :me do %>
          <.grant_card_me grant={@grant} membership={@membership} />
        <% else %>
          <.grant_card_profile
            grant={@grant}
            issuer_label={@issuer_label}
            issuer_membership={@issuer_membership}
            source_type_label={@source_type_label}
          />
        <% end %>
      </div>
    </div>
    """
  end

  attr :grant, :map, required: true
  attr :membership, :map, default: nil

  defp grant_card_me(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2">
      <span class="badge badge-sm badge-primary">
        {@grant.source.provider |> Atom.to_string() |> String.capitalize()}
      </span>

      <span class={grant_status_class(@grant)}>
        {@grant.status |> Atom.to_string()}
      </span>

      <span
        :if={@membership}
        class="ml-auto badge badge-sm bg-base-100 text-base-content/70"
        data-testid={"access-grant-membership-#{@grant.id}"}
      >
        {@membership.type |> Atom.to_string()}
      </span>
    </div>

    <div class="flex flex-wrap items-center gap-3">
      <img
        src={GoogleAvatarCache.cached_url(@grant.external_identity.avatar_url)}
        class="size-6 rounded-full"
      />
      <div>
        <.link
          class={[
            "font-bold flex items-center gap-1",
            "opacity-90 hover:opacity-100 transition",
            "space"
          ]}
          navigate={~p"/#{@grant.source.space.slug}/wiki"}
        >
          <span>{@grant.source.space.name}</span>
          <.icon
            name="hero-arrow-up-right-micro"
            class="opacity-50 space-hover:opacity-100 transition"
          />
        </.link>

        <div class="text-sm opacity-70">
          as {identity_label(@grant.external_identity)}
        </div>
      </div>
    </div>

    <div class="text-xs opacity-60 flex items-center gap-1">
      <.icon name="hero-shield-check-micro" class="" />
      Verified {@grant.last_verified_at |> Utils.Time.relative()} ago
    </div>
    """
  end

  attr :grant, :map, required: true
  attr :issuer_label, :string, required: true
  attr :issuer_membership, :map, default: nil
  attr :source_type_label, :string, required: true

  defp grant_card_profile(assigns) do
    ~H"""
    <div>
      <dl class={[
        "grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-xs",
        "[&>dt]:font-semibold",
        "[&>dt]:leading-tight",
        "[&>dt]:text-base-content/70"
      ]}>
        <dt>Granted by</dt>
        <dd data-testid={"access-grant-issuer-#{@grant.id}"}>
          <.link
            :if={@issuer_membership}
            navigate={~p"/#{@grant.source.space.slug}/wiki/members/#{@issuer_membership.username}"}
            class="link link-hover underline decoration-dashed underline-offset-2"
          >
            {@issuer_label}
          </.link>
          <span :if={!@issuer_membership}>{@issuer_label}</span>
        </dd>

        <dt>Via</dt>
        <dd data-testid={"access-grant-via-#{@grant.id}"}>{@source_type_label}</dd>

        <dt :if={is_binary(source_title(@grant.source))}>
          {source_container_label(@grant.source)}
        </dt>
        <dd
          :if={is_binary(source_title(@grant.source))}
          data-testid={"access-grant-source-title-#{@grant.id}"}
        >
          <span class="tooltip" data-tip={"id: #{source_group_id(@grant.source)}"}>
            {source_title(@grant.source)}
          </span>
        </dd>

        <dt>As</dt>
        <dd data-testid={"access-grant-identity-#{@grant.id}"}>
          {identity_label(@grant.external_identity)}
        </dd>

        <dt>Since</dt>
        <dd>
          <Time.relative_and_precise datetime={@grant.inserted_at} />
        </dd>

        <dt>Verified</dt>
        <dd>
          <Time.relative_and_precise datetime={@grant.last_verified_at} />
        </dd>

        <dt>Status</dt>
        <dd data-testid={"access-grant-status-#{@grant.id}"}>
          <span class={grant_status_class(@grant)}>
            {@grant.status |> Atom.to_string()}
          </span>
        </dd>
      </dl>
    </div>
    """
  end

  def identity_label(%{provider: :telegram, username: username}) when is_binary(username) do
    "@#{username}"
  end

  def identity_label(%{display_name: display_name}) when is_binary(display_name) do
    display_name
  end

  def identity_label(%{provider: provider, provider_user_id: provider_user_id}) do
    "#{provider}:#{provider_user_id}"
  end

  defp grant_status_class(%{status: :active}), do: "badge badge-sm badge-success"
  defp grant_status_class(_grant), do: "badge badge-sm badge-neutral"

  defp grant_membership(%{source: %{space: %{memberships: memberships}}}, %{id: user_id}) do
    Enum.find(memberships, &(&1.user_id == user_id))
  end

  defp grant_membership(_grant, _current_user), do: nil

  defp issuer_label(%{granted_by_user: granted_by_user}, issuer_membership)
       when not is_nil(granted_by_user) do
    case issuer_membership do
      %{username: username} -> username
      nil -> fallback_issuer_label(granted_by_user)
    end
  end

  defp issuer_label(%{source: %{claimed_by_user: nil}}, _issuer_membership), do: "Unknown"

  defp issuer_label(%{source: %{claimed_by_user: claimed_by_user}}, issuer_membership) do
    case issuer_membership do
      %{username: username} -> username
      nil -> fallback_issuer_label(claimed_by_user)
    end
  end

  defp issuer_membership(%{
         granted_by_user: %{id: granted_by_user_id},
         source: %{space: %{memberships: memberships}}
       }) do
    Enum.find(
      memberships,
      &(&1.user_id == granted_by_user_id and is_binary(&1.username) and &1.username != "")
    )
  end

  defp issuer_membership(%{
         source: %{claimed_by_user: %{id: claimed_by_user_id}, space: %{memberships: memberships}}
       }) do
    Enum.find(
      memberships,
      &(&1.user_id == claimed_by_user_id and is_binary(&1.username) and &1.username != "")
    )
  end

  defp issuer_membership(_grant), do: nil

  defp fallback_issuer_label(%{email: email}) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first()
  end

  defp fallback_issuer_label(claimed_by_user), do: to_string(claimed_by_user)

  defp source_type_label(%{provider: :telegram, metadata: %{"chat" => %{"type" => "channel"}}}),
    do: "Telegram channel membership"

  defp source_type_label(%{provider: :telegram, metadata: %{"chat" => %{"type" => type}}})
       when type in ["group", "supergroup"],
       do: "Telegram group membership"

  defp source_type_label(%{provider: :telegram}), do: "telegram source"
  defp source_type_label(%{provider: :google}), do: "Google account"
  defp source_type_label(%{provider: provider}), do: provider |> Atom.to_string()

  defp source_container_label(%{
         provider: :telegram,
         metadata: %{"chat" => %{"type" => "channel"}}
       }),
       do: "Channel"

  defp source_container_label(%{provider: :google}), do: nil
  defp source_container_label(_source), do: "Group"

  defp source_title(%{provider: :google}), do: nil

  defp source_title(%{title: title}) when is_binary(title) and title != "", do: title

  defp source_title(%{metadata: %{"chat" => %{"title" => title}}}) when is_binary(title),
    do: title

  defp source_title(_source), do: nil

  defp source_group_id(%{provider_source_id: provider_source_id})
       when is_binary(provider_source_id) and provider_source_id != "",
       do: provider_source_id

  defp source_group_id(%{metadata: %{"chat" => %{"id" => id}}}) when is_integer(id),
    do: Integer.to_string(id)

  defp source_group_id(%{metadata: %{"chat" => %{"id" => id}}}) when is_binary(id), do: id
  defp source_group_id(_source), do: nil
end
