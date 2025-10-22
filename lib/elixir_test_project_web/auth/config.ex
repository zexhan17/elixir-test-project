defmodule ElixirTestProjectWeb.Auth.Config do
  @moduledoc """
  Provides a thin layer around runtime configuration for authentication values.

  All helpers return sane, positive integers and fall back to the compile-time
  defaults defined in `config/config.exs` when runtime overrides are absent.
  """

  @app :elixir_test_project
  @jwt_default Application.compile_env(@app, :joken_expires_time_in_days, 1)
  @ttl_default Application.compile_env(@app, :jti_revoked_ttl_days, 30)
  @cleanup_default Application.compile_env(@app, :jti_revoked_cleanup_interval_hours, 24)

  @spec jwt_expires_days() :: pos_integer()
  def jwt_expires_days do
    fetch_integer(:joken_expires_time_in_days, @jwt_default)
  end

  @spec revoked_ttl_days() :: pos_integer()
  def revoked_ttl_days do
    fetch_integer(:jti_revoked_ttl_days, @ttl_default)
  end

  @spec cleanup_interval_hours() :: pos_integer()
  def cleanup_interval_hours do
    fetch_integer(:jti_revoked_cleanup_interval_hours, @cleanup_default)
  end

  defp fetch_integer(key, default) when is_atom(key) and is_integer(default) and default > 0 do
    key
    |> Application.get_env(@app, default)
    |> normalize_integer(default)
  end

  defp normalize_integer(value, _default) when is_integer(value) and value > 0, do: value
  defp normalize_integer(_value, default), do: default
end
