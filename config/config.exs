# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :elixir_test_project,
  ecto_repos: [ElixirTestProject.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :elixir_test_project, ElixirTestProjectWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: ElixirTestProjectWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ElixirTestProject.PubSub,
  live_view: [signing_salt: "MtEzaZ5g"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :elixir_test_project, ElixirTestProject.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configure Joken default signer for generating JWTs. The actual
# signing secret is read at runtime from the JOKEN_SIGNING_SECRET
# environment variable or from the endpoint secret_key_base.
config :joken, default_signer: "HS256"

# Default application-level values for JWT expiration and revoked-token cleanup.
# These are sensible defaults but can be overridden at runtime via environment
# variables. Values documented here mirror the env var names used at runtime.
config :elixir_test_project,
  joken_expires_time_in_days: 1,
  jti_revoked_ttl_days: 30,
  jti_revoked_cleanup_interval_hours: 24

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
