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
# JWT / token retention configuration
# -----------------------------------------------------------------------------
config :elixir_test_project,
  joken_expires_time_in_days: env!("JOKEN_EXPIRES_TIME_IN_DAYS", :integer, 1),
  jti_revoked_ttl_days: env!("JTI_REVOKED_TTL_DAYS", :integer, 30),
  jti_revoked_cleanup_interval_hours: env!("JTI_REVOKED_CLEANUP_INTERVAL_HOURS", :integer, 24)

# -----------------------------------------------------------------------------
# Google OAuth configuration
# -----------------------------------------------------------------------------
config :elixir_test_project, :google_oauth,
  client_id: env!("GOOGLE_CLIENT_ID", :string!),
  client_secret: env!("GOOGLE_CLIENT_SECRET", :string!),
  callback_url: env!("GOOGLE_CALLBACK_URL", :string!)

# -----------------------------------------------------------------------------
# Media storage (MinIO / S3 compatible) configuration
# -----------------------------------------------------------------------------
minio_endpoint = env!("MINIO_ENDPOINT", :string, "http://127.0.0.1:9000")
parsed_endpoint = URI.parse(minio_endpoint)
use_ssl? = env!("MINIO_USE_SSL", :string, "false") == "true"
scheme = if use_ssl?, do: "https://", else: "http://"
media_bucket = env!("BUCKET_NAME", :string, "elixir")

config :elixir_test_project, :media_storage,
  bucket: media_bucket,
  endpoint: minio_endpoint

config :ex_aws,
  access_key_id: env!("MINIO_ROOT_USER", :string!),
  secret_access_key: env!("MINIO_ROOT_PASSWORD", :string!),
  json_codec: Jason,
  region: env!("AWS_REGION", :string, "us-east-1")

config :ex_aws, :s3,
  scheme: scheme,
  host: parsed_endpoint.host || "127.0.0.1",
  port: parsed_endpoint.port || if(use_ssl?, do: 443, else: 80),
  virtual_host: false

# -----------------------------------------------------------------------------
# CORS configuration
# -----------------------------------------------------------------------------
allowed_origins =
  env!("origins", :string, "http://localhost:5173,http://localhost:5174")
  |> String.split(",", trim: true)

config :cors_plug, origin: allowed_origins

# make them available to DynamicCorsPlug
config :elixir_test_project, :cors_origins, allowed_origins

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
  ALLOWED_ORIGINS: #{inspect(allowed_origins)}
""")
