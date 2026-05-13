defmodule WikWeb.Plugs.SetTenantFromGroup do
  @behaviour Plug

  import Plug.Conn
  alias Ash.PlugHelpers
  alias Wik.Accounts

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case conn.path_params["group_slug"] do
      nil ->
        conn

      group_slug ->
        case Accounts.get_group_by_slug(group_slug, authorize?: false) do
          {:ok, _group} ->
            conn
            |> PlugHelpers.set_tenant(group_slug)
            |> assign(:current_scope, %{tenant: group_slug})

          {:error, _reason} ->
            raise Phoenix.Router.NoRouteError, conn: conn, router: WikWeb.Router
        end
    end
  end
end
