defmodule ElixirPhoenix.AuthPlug do
  import Plug.Conn
  alias ElixirPhoenix.Auth

  @behaviour Plug

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    case (conn |> fetch_cookies() |> Map.get(:cookies, %{}))["auth_token"] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> halt()

      token ->
        case Auth.verify_jwt(token) do
          {:ok, claims} ->
            assign(conn, :current_user, claims["sub"])

          {:error, _reason} ->
            conn
            |> put_status(:unauthorized)
            |> halt()
        end
    end
  end
end
