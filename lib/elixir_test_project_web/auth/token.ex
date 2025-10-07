defmodule ElixirTestProjectWeb.Auth.Token do
  @moduledoc """
  JWT helpers and centralized token behavior for the application.

  - `signer/0` constructs a runtime signer using a secure secret.
  - `prepare_claims/1` ensures tokens include `jti` and `exp` claims and
    normalizes claim keys to strings.
  - `normalize_claims/1` and `user_id_from_claims/1` provide a single place
    to reason about claim shapes.
  """
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
    # Prefer runtime configuration; allow overriding via env var for releases.
    secret_from_config =
      Application.get_env(:elixir_test_project, ElixirTestProjectWeb.Endpoint)[:secret_key_base]

    secret =
      case System.get_env("JOKEN_SIGNING_SECRET") do
        nil -> secret_from_config
        v -> String.trim(v)
      end

    secret = if is_binary(secret), do: String.trim(secret), else: secret

    # Enforce a minimum secret length to avoid weak signing keys
    min_len = 32

    if not (is_binary(secret) and String.length(secret) >= min_len) do
      raise "JWT signing secret not configured or is too short. Provide JOKEN_SIGNING_SECRET (>= #{min_len} chars) or set a proper :secret_key_base"
    end

    Joken.Signer.create("HS256", secret)
  end

  @spec signer() :: Joken.Signer.t()

  @doc """
  Prepare claims (add `jti` and `exp`) and return the normalized claims map.

  This function guarantees the returned map uses string keys and contains
  `"jti"` and `"exp"` claims. Use this before generating a token.
  """
  @spec prepare_claims(map()) :: map()

  def prepare_claims(claims) when is_map(claims) do
    jti = Ecto.UUID.generate()

    claims
    |> Map.put("jti", jti)
    |> add_exp()
    |> normalize_claims()
  end

  defp add_exp(claims) when is_map(claims) do
    secs = expires_in_seconds()
    exp = DateTime.utc_now() |> DateTime.add(secs, :second) |> DateTime.to_unix()
    Map.put(claims, "exp", exp)
  end

  defp expires_in_seconds do
    days = ElixirTestProjectWeb.Auth.Config.jwt_expires_days()
    days * 24 * 60 * 60
  end

  @doc """
  Normalize a claims map so keys are strings. Joken returns maps with
  binary keys but callers may supply atom keys; normalize to string keys for
  consistent lookups and to make tokens JSON-friendly.
  """
  @spec normalize_claims(map()) :: map()
  def normalize_claims(claims) when is_map(claims) do
    claims
    |> Enum.map(fn
      {k, v} when is_atom(k) -> {to_string(k), v}
      {k, v} when is_binary(k) -> {k, v}
      {k, v} -> {to_string(k), v}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Extract a canonical user id from token claims. Accepts several common
  claim keys: "user_id", "id", "sub" (either string or atom keys). Returns
  nil if no user id claim is present.
  """
  @spec user_id_from_claims(map()) :: String.t() | nil
  def user_id_from_claims(claims) when is_map(claims) do
    m = normalize_claims(claims)
    Map.get(m, "user_id") || Map.get(m, "id") || Map.get(m, "sub")
  end
end
