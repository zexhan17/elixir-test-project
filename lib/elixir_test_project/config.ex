defmodule ElixirTestProject.Config do
  @moduledoc """
  Centralised access point for runtime configuration and secrets.

  All modules should depend on this module (instead of calling `System.get_env/1`
  or `Application.get_env/3` directly) so that secrets are fetched in a single
  place and consistent defaults are applied project-wide.
  """

  @app :elixir_test_project
  @min_jwt_secret_length 32

  @doc """
  Returns the signing secret used for JWT tokens.

  Prefers `JOKEN_SIGNING_SECRET` when present and falls back to the Phoenix
  endpoint `:secret_key_base`. The secret must be at least #{@min_jwt_secret_length}
  characters.
  """
  @spec jwt_signing_secret() :: String.t()
  def jwt_signing_secret do
    case env_string("JOKEN_SIGNING_SECRET") do
      secret when is_binary(secret) and byte_size(secret) >= @min_jwt_secret_length ->
        secret

      secret when is_binary(secret) and secret != "" ->
        raise_invalid_secret!("JOKEN_SIGNING_SECRET")

      _ ->
        secret_key_base()
    end
  end

  @doc """
  Returns the Phoenix endpoint secret key base.
  """
  @spec secret_key_base() :: String.t()
  def secret_key_base do
    endpoint_config()
    |> Keyword.fetch!(:secret_key_base)
    |> ensure_binary!("secret_key_base")
  end

  @doc """
  Returns the optional DNS cluster query string or `:ignore` if not set.
  """
  @spec dns_cluster_query() :: String.t() | :ignore
  def dns_cluster_query do
    case Application.get_env(@app, :dns_cluster_query) do
      nil -> :ignore
      "" -> :ignore
      query -> query
    end
  end

  @doc """
  Returns the configured CORS origins list.
  """
  @spec cors_origins() :: [String.t()]
  def cors_origins do
    Application.get_env(@app, :cors_origins, [])
  end

  @doc """
  Returns request headers allowed for CORS preflight.
  """
  @spec cors_request_headers(default :: [String.t()]) :: [String.t()]
  def cors_request_headers(default \\ ["authorization", "content-type", "accept", "origin"]) do
    Application.get_env(@app, :cors_request_headers, default)
  end

  @doc """
  Returns response headers exposed to the browser for CORS requests.
  """
  @spec cors_expose_headers(default :: [String.t()]) :: [String.t()]
  def cors_expose_headers(default \\ ["authorization"]) do
    Application.get_env(@app, :cors_expose_headers, default)
  end

  @doc """
  Returns the configured CORS max-age in seconds.
  """
  @spec cors_max_age(default :: non_neg_integer()) :: non_neg_integer()
  def cors_max_age(default \\ 86_400) do
    Application.get_env(@app, :cors_max_age, default)
  end

  defp endpoint_config do
    Application.get_env(@app, ElixirTestProjectWeb.Endpoint, [])
  end

  defp env_string(name) when is_binary(name) do
    case System.get_env(name) do
      nil -> nil
      value -> String.trim(value)
    end
  end

  defp ensure_binary!(value, label) do
    if is_binary(value) and value != "" do
      value
    else
      raise "#{label} must be a non-empty string"
    end
  end

  defp raise_invalid_secret!(name) do
    raise """
    #{name} must be at least #{@min_jwt_secret_length} characters long.
    Update the environment variable or rely on the endpoint secret_key_base.
    """
  end
end
