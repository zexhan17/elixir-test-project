defmodule ElixirTestProjectWeb.Router do
  use ElixirTestProjectWeb, :router

  pipeline :api do
    plug :accepts, ["json", "multipart"]

    plug Plug.Parsers,
      parsers: [:urlencoded, :multipart, :json],
      pass: ["*/*"],
      json_decoder: Phoenix.json_library()

    plug OpenApiSpex.Plug.PutApiSpec, module: ElixirTestProjectWeb.ApiSpec
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
      post "/update-profile", UsersController, :update_profile
    end

    # Public media endpoints (no auth required)
    scope "/media" do
      get "/stream/:id", MediaController, :stream_media
    end

    # Protected media endpoints (auth required)
    scope "/media" do
      pipe_through :auth
      get "/", MediaController, :get_media
      get "/signed-url/:id", MediaController, :signed_url
      post "/upload", MediaController, :upload
    end

    scope "/gigs" do
      get "/categories", GigCategoryController, :index
      get "/types", GigTypeController, :index
      get "/", GigController, :index
      get "/:id", GigController, :show
    end

    scope "/gigs" do
      pipe_through :auth

      post "/categories", GigCategoryController, :create
      patch "/categories/:id", GigCategoryController, :update
      delete "/categories/:id", GigCategoryController, :delete

      post "/types", GigTypeController, :create
      patch "/types/:id", GigTypeController, :update
      delete "/types/:id", GigTypeController, :delete

      post "/", GigController, :create
      patch "/:id", GigController, :update
      delete "/:id", GigController, :delete
      post "/:id/activate", GigController, :activate
      post "/:id/deactivate", GigController, :deactivate
    end

    scope "/", alias: false do
      get "/openapi.json", OpenApiSpex.Plug.RenderSpec, []

      get "/docs", OpenApiSpex.Plug.SwaggerUI,
        otp_app: :elixir_test_project,
        path: "/api/openapi.json",
        display_operation_id: true
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
