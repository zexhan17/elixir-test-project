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
  socket "/socket", ElixirTestProjectWeb.UserSocket

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

  # ✅ Catch runtime exceptions for /api routes and return JSON
  plug :catch_api_exceptions_as_json

  plug ElixirTestProjectWeb.Router

  # =============================================
  # 🔥 Exception catcher for /api routes
  # =============================================
  defp catch_api_exceptions_as_json(conn, _opts) do
    if String.starts_with?(conn.request_path, "/api") do
      try do
        conn
      rescue
        exception ->
          require Logger

          Logger.error("""
          ⚠️ API Crash Caught
          Path: #{conn.request_path}
          Exception: #{inspect(exception)}
          Stacktrace:
          #{Exception.format(:error, exception, __STACKTRACE__)}
          """)

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.put_status(:internal_server_error)
          |> Phoenix.Controller.json(%{
            error: "internal_server_error",
            message: Exception.message(exception),
            type: inspect(exception.__struct__)
          })
          |> Plug.Conn.halt()
      catch
        kind, reason ->
          require Logger

          Logger.error("""
          ⚠️ Non-standard crash (#{kind})
          Path: #{conn.request_path}
          Reason: #{inspect(reason)}
          Stacktrace:
          #{Exception.format(kind, reason, __STACKTRACE__)}
          """)

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.put_status(:internal_server_error)
          |> Phoenix.Controller.json(%{
            error: "unexpected_crash",
            message: inspect(reason),
            kind: to_string(kind)
          })
          |> Plug.Conn.halt()
      end
    else
      conn
    end
  end
end
