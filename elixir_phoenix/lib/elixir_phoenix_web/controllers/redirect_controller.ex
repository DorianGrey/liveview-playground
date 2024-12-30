defmodule ElixirPhoenixWeb.RedirectController do
  use ElixirPhoenixWeb, :controller

  def index(conn, _params) do
    redirect(conn, to: "/login")
  end
end
