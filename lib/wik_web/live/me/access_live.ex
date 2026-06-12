defmodule WikWeb.Me.AccessLive do
  use WikWeb, :live_view

  alias Utils.Log
  alias Wik.Access
  alias Wik.Accounts
  alias WikWeb.Components
  alias WikWeb.GoogleAvatarCache

  on_mount {WikWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    current_user = socket.assigns.current_user
    spaces = scope |> list_spaces()
    identities = current_user |> list_user_external_identities()
    grants = current_user |> list_user_grants()
    owned_spaces = current_user |> list_owned_spaces()

    {:ok,
     socket
     |> assign(grants: grants)
     |> assign(spaces: spaces)
     |> assign(identities: identities)
     |> assign(owned_spaces: owned_spaces)}
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
              :if={grant_bypass_messages?(@current_user, @owned_spaces)}
              class="space-y-2 mb-2"
              data-testid="me-access-bypasses"
            >
              <.superadmin_bypass_message :if={@current_user.role == :superadmin} />
              <.owner_bypass_message :if={@owned_spaces != []} spaces={@owned_spaces} />
            </div>

            <div :if={@grants == []} class="card bg-base-200 h-min">
              <div class="card-body py-4 text-sm opacity-70">
                No access grants yet.
              </div>
            </div>

            <div :if={@grants != []} class="space-y-2" data-testid="me-access-grants">
              <Components.Membership.Access.grant_card
                :for={grant <- @grants}
                current_user={@current_user}
                grant={grant}
                variant={:me}
              />
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
        <img src={GoogleAvatarCache.cached_url(@identity.avatar_url)} class="size-10 rounded-full" />
        <div>
          <div class="font-bold">{Components.Membership.Access.identity_label(@identity)}</div>
          <div class="badge badge-xs bg-base-300 text-base-content/50">
            id: {@identity.provider_user_id}
          </div>
        </div>
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

  attr :spaces, :list, required: true

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
            :for={space <- @spaces}
            class={[
              "badge badge-sm badge-neutral",
              "opacity-90 hover:opacity-100 transition"
            ]}
            navigate={~p"/#{space.slug}/wiki"}
          >
            {space.name}
          </.link>
        </div>
      </div>
    </.card>
    """
  end

  defp list_spaces(nil), do: []

  defp list_spaces(scope) do
    with {:ok, spaces} <- Accounts.list_spaces(scope: scope) do
      spaces
    else
      err ->
        Log.scoped_error(scope, err, "list_spaces failed")
        []
    end
  end

  defp list_owned_spaces(nil), do: []

  defp list_owned_spaces(user) do
    with {:ok, spaces} <- Accounts.list_owned_spaces(user) do
      spaces
    else
      err ->
        Log.scoped_error(nil, err, "list_owned_spaces failed")
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

  defp grant_bypass_messages?(%{role: :superadmin}, _owned_spaces), do: true
  defp grant_bypass_messages?(_user, owned_spaces), do: owned_spaces != []
end
