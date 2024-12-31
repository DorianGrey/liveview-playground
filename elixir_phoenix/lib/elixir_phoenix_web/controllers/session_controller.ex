defmodule ElixirPhoenixWeb.SessionController do
  use ElixirPhoenixWeb, :controller

  def set_jwt_cookie_and_redirect(conn, %{"jwt" => jwt}) do
    conn
    |> put_resp_cookie("auth_token", jwt, http_only: true, max_age: 2 * 60 * 60)
    |> redirect(to: "/app/dashboard")
  end

  def logout(conn) do
    conn
    |> delete_resp_cookie("auth_token")
    |> redirect(to: "/login")
  end
end
