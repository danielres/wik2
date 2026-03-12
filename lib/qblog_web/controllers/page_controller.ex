defmodule QblogWeb.PageController do
  use QblogWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
