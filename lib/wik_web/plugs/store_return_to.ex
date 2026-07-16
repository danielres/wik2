defmodule WikWeb.Plugs.StoreReturnTo do
  @moduledoc false

  import Plug.Conn

  def init(opts), do: opts

  def call(%{assigns: %{current_user: current_user}} = conn, _opts) when not is_nil(current_user),
    do: conn

  def call(conn, _opts), do: put_session(conn, :return_to, current_path(conn))

  defp current_path(%{request_path: path, query_string: ""}), do: path
  defp current_path(%{request_path: path, query_string: query}), do: path <> "?" <> query
end
