defmodule QblogWeb.WikiRedirectController do
  use QblogWeb, :controller

  def home(conn, _params) do
    redirect(conn, to: ~p"/#{conn.params["group_name"]}/wiki/home")
  end
end
