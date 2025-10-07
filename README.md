# ElixirTestProject

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Reset local development DB

If you changed primary key types or migrations and want to recreate the local SQLite dev DB, use the included Mix task (destructive):

```cmd
mix reset.dev_db
```

This deletes `elixir_test_project_dev.db` (and its -shm/-wal files), runs `mix ecto.create` and `mix ecto.migrate`. Only run it in development — it is destructive.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## Environment variables and configuration

This project reads a few environment variables related to JWTs and revoked-token
cleanup. Sensible defaults are provided in `config/config.exs` but you can
override them via environment variables or runtime config.

- JOKEN_EXPIRES_TIME_IN_DAYS (env) / `:elixir_test_project, :joken_expires_time_in_days` (config)
	- How long newly issued JWTs are valid, in days.
	- Default: 1 (day).

- JTI_REVOKED_TTL_DAYS (env) / `:elixir_test_project, :jti_revoked_ttl_days` (config)
	- How long revoked JTI records are retained in the database before cleanup.
	- Default: 30 (days).

- JTI_REVOKED_CLEANUP_INTERVAL_HOURS (env) / `:elixir_test_project, :jti_revoked_cleanup_interval_hours` (config)
	- How often the background cleanup job runs to prune old revoked-token rows.
	- Default: 24 (hours).

For development convenience, `config/runtime.exs` loads a `.env` file when running
in the `:dev` environment. You can add these variables into `.env` for local
testing.

## Security and production readiness

This section documents recommended security practices and operational guidance
for running this application in production.

- Secrets and signing keys
	- Never check secrets into source control. Use a secrets manager or your
		platform's runtime environment variables.
	- The JWT signing secret must be long and unpredictable. We require a
		minimum of 32 characters for `JOKEN_SIGNING_SECRET` or a robust
		`secret_key_base` provided to the Phoenix endpoint. Prefer using a key
		stored in a cloud KMS and injected at runtime.

- Token lifetimes and refresh
	- Keep JWT lifetimes short (minutes to hours) for sensitive applications.
		The default in this project is 1 day for convenience. Adjust
		`JOKEN_EXPIRES_TIME_IN_DAYS` to a smaller value if you need stronger
		guarantees.
	- Implement refresh token flows and rotate refresh tokens where needed.

- Revocation and cleanup
	- Revoked JTIs are stored in the `revoked_tokens` table. This allows
		immediate revocation on logout.
	- The cleaner job prunes old revoked records after the configured TTL. For
		high-throughput systems, consider using an in-memory or distributed cache
		(Redis) with expiration to reduce DB load.

- Transport and cookies
	- Always use TLS (HTTPS) in production. If tokens are stored in cookies,
		mark them as `Secure` and `HttpOnly` and use proper SameSite settings.

- Operational
	- Monitor auth-related metrics (token issuance, revocations, failed
		verifications) and set alerts for abnormal activity.
	- Back up the database regularly and test restore procedures.

If you want, I can add a short `DEPLOY.md` with example commands for common
platforms (Heroku/GCP/AWS) showing secure ways to inject secrets and env vars.
