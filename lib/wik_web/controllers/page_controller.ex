defmodule WikWeb.PageController do
  use WikWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def privacy(conn, _params) do
    public_host = WikWeb.Endpoint.struct_url().host || "localhost"
    render(conn, :privacy, public_host: public_host)
  end

  def terms(conn, _params) do
    render(conn, :terms)
  end
end
