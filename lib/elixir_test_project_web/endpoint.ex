defmodule ElixirTestProjectWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :elixir_test_project

  @session_options [
    store: :cookie,
    key: "_elixir_test_project_key",
    signing_salt: "excVD3dK",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  # Add user socket for tracking presence
  socket "/socket", ElixirTestProjectWeb.UserSocket,
    websocket: true,
    longpoll: false

  # Serve static files
  plug Plug.Static,
    at: "/",
    from: :elixir_test_project,
    gzip:
      Application.compile_env(
        :elixir_test_project,
        [ElixirTestProjectWeb.Endpoint, :code_reloader],
        false
      ) == false,
    only: ElixirTestProjectWeb.static_paths()

  # Enable code reloading in dev
  if Application.compile_env(
       :elixir_test_project,
       [ElixirTestProjectWeb.Endpoint, :code_reloader],
       false
     ) do
    plug Phoenix.CodeReloader
    plug ElixirTestProjectWeb.Plugs.ApiCheckRepoStatusPlug, otp_app: :elixir_test_project
  end

  plug Phoenix.LiveDashboard.RequestLogger,
    param_key: "request_logger",
    cookie_key: "request_logger"

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  # CORS handling via custom DynamicCorsPlug
  plug ElixirTestProjectWeb.Plugs.DynamicCorsPlug

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head
  plug Plug.Session, @session_options
  plug ElixirTestProjectWeb.Router
end
