defmodule ElixirPhoenixWeb.Router do
  use ElixirPhoenixWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixirPhoenixWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :private do
    plug ElixirPhoenix.AuthPlug
  end

  scope "/", ElixirPhoenixWeb do
    pipe_through :browser

    get "/set_jwt_cookie_and_redirect", SessionController, :set_jwt_cookie_and_redirect

    get "/", RedirectController, :index
    live "/login", LoginController
    live "/registration", RegistrationController
  end

  scope "/app", ElixirPhoenixWeb do
    pipe_through [:browser, :private]

    live "/dashboard", DashboardController
  end

  # Other scopes may use custom stacks.
  # scope "/api", ElixirPhoenixWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixir_phoenix, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElixirPhoenixWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
