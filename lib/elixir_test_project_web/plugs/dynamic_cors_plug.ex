defmodule ElixirTestProjectWeb.Plugs.DynamicCorsPlug do
  @moduledoc """
  Runtime wrapper around CORSPlug that resolves options from application env
  on each request. This ensures values set in `runtime.exs` (via
  `Application.put_env/3` at runtime) are applied for preflight and responses.
  """
  @behaviour Plug

  # no direct conn helpers required here; CORSPlug will handle the connection
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

  def call(conn, _opts) do
    cors_opts = [
      origin: Application.get_env(:elixir_test_project, :cors_origins, []),
      methods: @default_methods,
      headers: Application.get_env(:elixir_test_project, :cors_request_headers, @default_headers),
      expose: Application.get_env(:elixir_test_project, :cors_expose_headers, ["authorization"]),
      max_age: Application.get_env(:elixir_test_project, :cors_max_age, 86_400)
    ]

    # initialize CORSPlug with resolved opts and call it
    conn
    |> CORSPlug.call(CORSPlug.init(cors_opts))
  end
end
