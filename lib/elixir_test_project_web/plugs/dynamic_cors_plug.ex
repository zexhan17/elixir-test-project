defmodule ElixirTestProjectWeb.Plugs.DynamicCorsPlug do
  @moduledoc """
  Runtime wrapper around CORSPlug that resolves options from application env
  on each request. Ensures values set in `runtime.exs` are applied dynamically.
  """
  @behaviour Plug

  @default_headers [
    "authorization",
    "content-type",
    "accept",
    "origin",
    "x-requested-with",
    "x-csrf-token"
  ]

  @default_methods ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]

  def init(_opts), do: %{}

  def call(%Plug.Conn{method: "OPTIONS"} = conn, _opts) do
    # Always allow OPTIONS preflight without auth blocking
    apply_cors(conn)
  end

  def call(conn, _opts), do: apply_cors(conn)

  defp apply_cors(conn) do
    cors_opts = [
      origin: Application.get_env(:elixir_test_project, :cors_origins, []),
      methods: @default_methods,
      headers: Application.get_env(:elixir_test_project, :cors_request_headers, @default_headers),
      expose: Application.get_env(:elixir_test_project, :cors_expose_headers, ["authorization"]),
      max_age: Application.get_env(:elixir_test_project, :cors_max_age, 86_400)
    ]

    conn
    |> CORSPlug.call(CORSPlug.init(cors_opts))
  end
end
