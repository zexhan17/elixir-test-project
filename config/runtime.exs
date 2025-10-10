import Config
import Dotenvy

# -----------------------------------------------------------------------------
# Load .env files using Dotenvy
# -----------------------------------------------------------------------------
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./")

source!([
  Path.absname(".env", env_dir_prefix),
  Path.absname(".#{config_env()}.env", env_dir_prefix),
  System.get_env()
])

# -----------------------------------------------------------------------------
# Common values
# -----------------------------------------------------------------------------
config :elixir_test_project,
  env: config_env(),
  release_name: env!("RELEASE_NAME", :string, "dev")

# -----------------------------------------------------------------------------
# Phoenix Endpoint
# -----------------------------------------------------------------------------
config :elixir_test_project, ElixirTestProjectWeb.Endpoint,
  http: [port: env!("PORT", :integer, 4000)],
  secret_key_base: env!("SECRET_KEY_BASE", :string!),
  url: [
    host: env!("PHX_HOST", :string, "localhost"),
    port: env!("PORT", :integer, 4000)
  ],
  server: env!("PHX_SERVER", :string, "false") == "true"

# -----------------------------------------------------------------------------
# Database configuration
# -----------------------------------------------------------------------------
config :elixir_test_project, ElixirTestProject.Repo,
  database:
    env!("DATABASE_PATH", :string, "./elixir_test_project_dev.db")
    |> Path.expand(),
  pool_size: env!("POOL_SIZE", :integer, 5),
  adapter: Ecto.Adapters.SQLite3

# -----------------------------------------------------------------------------
# JWT configuration
# -----------------------------------------------------------------------------
config :elixir_test_project, :jwt,
  secret: env!("JOKEN_SIGNING_SECRET", :string),
  expires_in_days: env!("JOKEN_EXPIRES_TIME_IN_DAYS", :integer, 2)

# -----------------------------------------------------------------------------
# Google OAuth configuration
# -----------------------------------------------------------------------------
config :elixir_test_project, :google_oauth,
  client_id: env!("GOOGLE_CLIENT_ID", :string!),
  client_secret: env!("GOOGLE_CLIENT_SECRET", :string!),
  callback_url: env!("GOOGLE_CALLBACK_URL", :string!)

# -----------------------------------------------------------------------------
# CORS configuration
# -----------------------------------------------------------------------------
config :cors_plug,
  origin:
    env!("origins", :string, "http://localhost:5173,http://localhost:5174")
    |> String.split(",", trim: true)

# -----------------------------------------------------------------------------
# Optional DNS cluster (for distributed release setups)
# -----------------------------------------------------------------------------
# if dns_query = env!("DNS_CLUSTER_QUERY", :string, nil) do
#   config :libcluster,
#     topologies: [
#       dns_cluster: [
#         strategy: Elixir.Cluster.Strategy.DNSPoll,
#         config: [query: dns_query]
#       ]
#     ]
# end

# -----------------------------------------------------------------------------
# Print helpful info at startup
# -----------------------------------------------------------------------------
IO.puts("""
Loaded runtime config:
  ENV: #{config_env()}
  PORT: #{env!("PORT", :string, "4000")}
  DATABASE_PATH: #{Path.expand(env!("DATABASE_PATH", :string, "./elixir_test_project_dev.db"))}
""")
