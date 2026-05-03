defmodule WikWeb.PageController do
  use WikWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
