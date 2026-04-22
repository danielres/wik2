defmodule QblogWeb.MeLive do
  use QblogWeb, :live_view

  alias Qblog.Access
  alias Qblog.Accounts
  alias QblogWeb.Components
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    groups = scope |> list_groups()
    identities = socket.assigns.current_user |> list_user_external_identities()
    grants = socket.assigns.current_user |> list_user_grants()

    socket =
      socket
      |> assign(grants: grants)
      |> assign(groups: groups)
      |> assign(identities: identities)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.container>
        <h1 class="text-2xl font-[100] flex justify-between items-center">
          Your account
        </h1>

        <div class="grid gap-4 md:grid-cols-[1fr_1.2fr]">
          <div>
            <h2 class="text-lg mb-1">Connected identities</h2>

            <div :if={@identities == []} class="card bg-base-200 h-min">
              <div class="card-body py-4 text-sm opacity-70">
                No external identities connected yet.
              </div>
            </div>

            <div :if={@identities != []} class="space-y-2" data-testid="me-connected-identities">
              <.identity_card :for={identity <- @identities} identity={identity} />
            </div>
          </div>

          <div>
            <h2 class="text-lg mb-1">Access grants</h2>

            <div :if={@grants == []} class="card bg-base-200 h-min">
              <div class="card-body py-4 text-sm opacity-70">
                No access grants yet.
              </div>
            </div>

            <div :if={@grants != []} class="space-y-2" data-testid="me-access-grants">
              <.grant_card :for={grant <- @grants} grant={grant} />
            </div>
          </div>
        </div>
      </Layouts.container>
    </Layouts.app>
    """
  end

  slot :inner_block
  attr :rest, :global

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

  attr :grant, :map, required: true

  def grant_card(assigns) do
    dbg(assigns.grant.source.group.name)

    ~H"""
    <.card data-testid={"access-grant-#{@grant.id}"}>
      <div class="flex flex-wrap items-center gap-2">
        <span class="badge badge-sm badge-primary">
          {@grant.source.provider |> Atom.to_string() |> String.capitalize()}
        </span>

        <span class={grant_status_class(@grant)}>
          {@grant.status |> Atom.to_string()}
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
            navigate={~p"/#{@grant.source.group.name}/wiki"}
          >
            <span>{@grant.source.group.name}</span>
            <.icon name="hero-arrow-up-right-micro" class="opacity-50 group-hover:opacity-100 transition" />
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

  defp identity_label(%{provider: :telegram, username: username}) when is_binary(username) do
    "@#{username}"
  end

  defp identity_label(%{display_name: display_name}) when is_binary(display_name) do
    display_name
  end

  defp identity_label(%{provider: provider, provider_user_id: provider_user_id}) do
    "#{provider}:#{provider_user_id}"
  end

  defp source_label(%{group: %{name: name}}), do: name
  defp source_label(%{title: title}), do: title
end
