defmodule WikWeb.Me.AccessLive do
  use WikWeb, :live_view

  alias Utils.Log
  alias Wik.Access
  alias Wik.Accounts

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    current_user = socket.assigns.current_user
    groups = scope |> list_groups()
    identities = current_user |> list_user_external_identities()
    grants = current_user |> list_user_grants()
    owned_groups = current_user |> list_owned_groups()

    {:ok,
     socket
     |> assign(grants: grants)
     |> assign(groups: groups)
     |> assign(identities: identities)
     |> assign(owned_groups: owned_groups)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app context={@context} flash={@flash} scope={@current_scope}>
      <Layouts.me view="me/access">
        <div class="grid gap-4 md:grid-cols-[1fr_1.2fr]">
          <section>
            <h2 class="text-lg mb-1">Connected identities</h2>

            <div :if={@identities == []} class="card bg-base-200 h-min">
              <div class="card-body py-4 text-sm opacity-70">
                No external identities connected yet.
              </div>
            </div>

            <div :if={@identities != []} class="space-y-2" data-testid="me-connected-identities">
              <.identity_card :for={identity <- @identities} identity={identity} />
            </div>
          </section>

          <section>
            <h2 class="text-lg mb-1">Access grants</h2>

            <div
              :if={grant_bypass_messages?(@current_user, @owned_groups)}
              class="space-y-2 mb-2"
              data-testid="me-access-bypasses"
            >
              <.superadmin_bypass_message :if={@current_user.role == :superadmin} />
              <.owner_bypass_message :if={@owned_groups != []} groups={@owned_groups} />
            </div>

            <div :if={@grants == []} class="card bg-base-200 h-min">
              <div class="card-body py-4 text-sm opacity-70">
                No access grants yet.
              </div>
            </div>

            <div :if={@grants != []} class="space-y-2" data-testid="me-access-grants">
              <.grant_card :for={grant <- @grants} current_user={@current_user} grant={grant} />
            </div>
          </section>
        </div>
      </Layouts.me>
    </Layouts.app>
    """
  end

  slot :inner_block
  attr :rest, :global, default: %{}

  def card(assigns) do
    ~H"""
    <div
      class={[
        "card bg-base-200"
      ]}
      {@rest}
    >
      <div class="card-body gap-3 py-4">
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  attr :identity, :map, required: true

  def identity_card(assigns) do
    ~H"""
    <.card data-testid={"external-identity-#{@identity.id}"}>
      <div class="flex flex-wrap items-center gap-2">
        <span class="badge badge-sm badge-primary">
          {@identity.provider |> Atom.to_string() |> String.capitalize()}
        </span>
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <img src={@identity.avatar_url} class="size-10 rounded-full" />
        <div>
          <div class="font-bold">{@identity |> identity_label()}</div>
          <div class="badge badge-xs bg-base-300 text-base-content/50">
            id: {@identity.provider_user_id}
          </div>
        </div>
      </div>
    </.card>
    """
  end

  attr :current_user, :map, required: true
  attr :grant, :map, required: true

  def grant_card(assigns) do
    assigns =
      assign(
        assigns,
        :membership,
        get_grant_membership(assigns.grant, assigns.current_user)
      )

    ~H"""
    <.card data-testid={"access-grant-#{@grant.id}"}>
      <div class="flex flex-wrap items-center gap-2">
        <span class="badge badge-sm badge-primary">
          {@grant.source.provider |> Atom.to_string() |> String.capitalize()}
        </span>

        <span class={grant_status_class(@grant)}>
          {@grant.status |> Atom.to_string()}
        </span>

        <span
          class="ml-auto badge badge-sm bg-base-100 text-base-content/70"
          data-testid={"access-grant-membership-#{@grant.id}"}
        >
          {@membership.type |> Atom.to_string()}
        </span>
      </div>

      <div class="flex flex-wrap items-center gap-3">
        <img src={@grant.external_identity.avatar_url} class="size-10 rounded-full" />
        <div>
          <.link
            class={[
              "font-bold flex items-center gap-1",
              "opacity-90 hover:opacity-100 transition",
              "group"
            ]}
            navigate={~p"/#{@grant.source.group.slug}/wiki"}
          >
            <span>{@grant.source.group.name}</span>
            <.icon
              name="hero-arrow-up-right-micro"
              class="opacity-50 group-hover:opacity-100 transition"
            />
          </.link>

          <div class="text-sm opacity-70">
            as {@grant.external_identity |> identity_label()}
          </div>
        </div>
      </div>

      <div class="text-xs opacity-60 flex items-center gap-1">
        <.icon name="hero-shield-check-micro" class="" />
        Verified {@grant.last_verified_at |> Utils.Time.relative()} ago
      </div>
    </.card>
    """
  end

  def superadmin_bypass_message(assigns) do
    ~H"""
    <.card data-testid="superadmin-access-bypass">
      <div class="">
        <div class="flex items-center gap-1">
          <.icon name="hero-key-micro" class="" />
          <div class="font-bold">Superadmin</div>
        </div>
        <span class="opacity-70">
          As Superadmin, you have access to all spaces.
        </span>
      </div>
    </.card>
    """
  end

  attr :groups, :list, required: true

  def owner_bypass_message(assigns) do
    ~H"""
    <.card data-testid="owner-access-bypass">
      <div class="">
        <div class="flex items-center gap-1">
          <.icon name="hero-key-micro" class="" />
          <div class="font-bold">Owner</div>
        </div>
        <span class="opacity-70">
          As the space owner, you always keep access to:
        </span>

        <div class="flex flex-wrap gap-2 mt-2">
          <.link
            :for={group <- @groups}
            class={[
              "badge badge-sm badge-neutral",
              "opacity-90 hover:opacity-100 transition"
            ]}
            navigate={~p"/#{group.slug}/wiki"}
          >
            {group.name}
          </.link>
        </div>
      </div>
    </.card>
    """
  end

  defp list_groups(nil), do: []

  defp list_groups(scope) do
    with {:ok, groups} <- Accounts.list_groups(scope: scope) do
      groups
    else
      err ->
        Log.scoped_error(scope, err, "list_groups failed")
        []
    end
  end

  defp list_owned_groups(nil), do: []

  defp list_owned_groups(user) do
    with {:ok, groups} <- Accounts.list_owned_groups(user) do
      groups
    else
      err ->
        Log.scoped_error(nil, err, "list_owned_groups failed")
        []
    end
  end

  defp list_user_external_identities(nil), do: []

  defp list_user_external_identities(user) do
    with {:ok, identities} <- Access.list_user_external_identities(user) do
      identities
    else
      err ->
        Log.scoped_error(nil, err, "list_user_external_identities failed")
        []
    end
  end

  defp list_user_grants(nil), do: []

  defp list_user_grants(user) do
    with {:ok, grants} <- Access.list_user_grants(user) do
      grants
    else
      err ->
        Log.scoped_error(nil, err, "list_user_grants failed")
        []
    end
  end

  defp grant_status_class(%{status: :active}), do: "badge badge-sm badge-success"
  defp grant_status_class(_grant), do: "badge badge-sm badge-neutral"

  defp grant_bypass_messages?(%{role: :superadmin}, _owned_groups), do: true
  defp grant_bypass_messages?(_user, owned_groups), do: owned_groups != []

  defp get_grant_membership(%{source: %{group: %{memberships: memberships}}}, %{id: user_id}) do
    Enum.find(memberships, &(&1.user_id == user_id))
  end

  defp identity_label(%{provider: :telegram, username: username}) when is_binary(username) do
    "@#{username}"
  end

  defp identity_label(%{display_name: display_name}) when is_binary(display_name) do
    display_name
  end

  defp identity_label(%{provider: provider, provider_user_id: provider_user_id}) do
    "#{provider}:#{provider_user_id}"
  end
end
