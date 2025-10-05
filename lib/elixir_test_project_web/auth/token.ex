defmodule ElixirTestProjectWeb.Auth.Token do
  use Joken.Config
  @impl true
  def token_config do
    default_claims(skip: [:aud, :iss])
  end

  # Create a signer at runtime. We intentionally do not use @impl here
  # because Joken.Config doesn't define a signer/0 callback. The
  # signing secret is taken from JOKEN_SIGNING_SECRET env var first,
  # then falls back to the endpoint secret_key_base configured for the
  # current environment (dev/test/prod).
  def signer do
    secret =
      System.get_env("JOKEN_SIGNING_SECRET") ||
        Application.get_env(:elixir_test_project, ElixirTestProjectWeb.Endpoint)[:secret_key_base]

    if secret in [nil, ""] do
      raise "JWT signing secret not configured. Set JOKEN_SIGNING_SECRET or ensure :secret_key_base is set in your endpoint config"
    end

    Joken.Signer.create("HS256", secret)
  end
end
