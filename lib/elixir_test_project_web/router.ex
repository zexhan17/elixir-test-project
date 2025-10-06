defmodule ElixirTestProjectWeb.Router do
  use ElixirTestProjectWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    # Configure CORS using runtime config (origins set from env in runtime.exs)
    plug CORSPlug, origin: Application.compile_env(:elixir_test_project, :cors_origins, [])
    plug ElixirTestProjectWeb.Plugs.AuthenticateUserPlug
  end

  pipeline :auth do
    plug ElixirTestProjectWeb.Plugs.RequireAuthPlug
  end

  scope "/api", ElixirTestProjectWeb do
    pipe_through :api

    get "/", HealthController, :index

    # Health route remains at the top level

    # Group auth routes under /api/auth
    scope "/auth" do
      post "/register", UsersController, :register
      post "/login", UsersController, :login

      # Protected routes
      pipe_through :auth
      get "/verify-token", UsersController, :verify_token
      get "/refresh-token", UsersController, :refresh_token
    end
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixir_test_project, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ElixirTestProjectWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
