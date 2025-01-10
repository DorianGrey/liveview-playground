defmodule ElixirPhoenix.IsAuthenticatedPlug do
  import Plug.Conn
  import Phoenix.Controller
  alias ElixirPhoenix.Auth

  @behaviour Plug

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    case (conn |> fetch_cookies() |> Map.get(:cookies, %{}))["auth_token"] do
      nil ->
        redirect_to = URI.encode(conn.request_path)

        conn
        |> redirect(to: "/login?redirect_to=#{redirect_to}")
        |> halt()

      token ->
        case Auth.verify_jwt(token) do
          {:ok, claims} ->
            assign(conn, :current_user, claims["sub"])

          {:error, _reason} ->
            redirect_to = URI.encode(conn.request_path)

            conn
            |> delete_resp_cookie("auth_token")
            |> redirect(to: "/login?redirect_to=#{redirect_to}")
            |> halt()
        end
    end
  end
end
