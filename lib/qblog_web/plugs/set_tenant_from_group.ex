defmodule QblogWeb.Plugs.SetTenantFromGroup do
  @behaviour Plug

  import Plug.Conn
  alias Ash.PlugHelpers
  alias Qblog.Accounts

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case conn.path_params["group"] do
      nil ->
        conn

      group ->
        case Accounts.get_group_by_name(group) do
          {:ok, _group} ->
            conn
            |> PlugHelpers.set_tenant(group)
            |> assign(:current_scope, %{tenant: group})

          {:error, _reason} ->
            raise Phoenix.Router.NoRouteError, conn: conn, router: QblogWeb.Router
        end
    end
  end
end
