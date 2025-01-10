defmodule ElixirPhoenix.IsAnonymousPlug do
  import Plug.Conn
  import Phoenix.Controller

  @behaviour Plug

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    case (conn |> fetch_cookies() |> Map.get(:cookies, %{}))["auth_token"] do
      nil ->
        conn

      _token ->
        conn
        |> redirect(to: "/app/dashboard")
        |> halt()
    end
  end
end
