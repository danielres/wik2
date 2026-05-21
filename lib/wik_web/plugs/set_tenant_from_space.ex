defmodule WikWeb.Plugs.SetTenantFromSpace do
  @behaviour Plug

  import Plug.Conn
  alias Ash.PlugHelpers
  alias Wik.Accounts

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case conn.path_params["space_slug"] do
      nil ->
        conn

      space_slug ->
        case Accounts.get_space_by_slug(space_slug, authorize?: false) do
          {:ok, _space} ->
            conn
            |> PlugHelpers.set_tenant(space_slug)
            |> assign(:current_scope, %{tenant: space_slug})

          {:error, _reason} ->
            raise Phoenix.Router.NoRouteError, conn: conn, router: WikWeb.Router
        end
    end
  end
end
