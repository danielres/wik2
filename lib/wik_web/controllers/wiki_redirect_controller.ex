defmodule WikWeb.WikiRedirectController do
  use WikWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/#{conn.params["group_slug"]}/wiki/home")
  end
end
