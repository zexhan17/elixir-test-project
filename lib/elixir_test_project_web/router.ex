defmodule ElixirTestProjectWeb.Router do
  use ElixirTestProjectWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
    plug ElixirTestProjectWeb.Plugs.DynamicCorsPlug
    plug ElixirTestProjectWeb.Plugs.AuthenticateUserPlug
  end

  pipeline :auth do
    plug ElixirTestProjectWeb.Plugs.RequireAuthPlug
  end

  scope "/api", ElixirTestProjectWeb do
    pipe_through :api

    get "/", HealthController, :index

    # Auth routes
    scope "/auth" do
      post "/register", AuthController, :register
      post "/login", AuthController, :login

      pipe_through :auth
      get "/verify-token", AuthController, :verify_token
      post "/logout", AuthController, :logout
      get "/refresh-token", AuthController, :refresh_token
    end

    scope "/user" do
      get "/get-google-redirect-link", UsersController, :get_google_redirect_link
      get "/connect-google", UsersController, :connect_google
      get "/is-connected", UsersController, :is_google_connected
      post "/upload-image", UsersController, :upload_to_google
      post "/update-profile", UsersController, :update_profile
    end

    # ✅ Catch-all for unmatched /api routes
    match :*, "/*path", ErrorController, :not_found
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:elixir_test_project, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through [:fetch_session, :protect_from_forgery]

      live_dashboard "/dashboard", metrics: ElixirTestProjectWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
