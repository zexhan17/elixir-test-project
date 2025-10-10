defmodule ElixirTestProjectWeb.Auth.Config do
  @moduledoc """
  Reads authentication-related configuration directly from runtime.exs.

  This module no longer checks environment variables or provides defaults.
  If a value is not configured in `runtime.exs`, it returns `nil`.
  """

  @app :elixir_test_project

  @spec jwt_expires_days() :: integer() | nil
  def jwt_expires_days do
    Application.get_env(@app, :joken_expires_time_in_days)
  end

  @spec revoked_ttl_days() :: integer() | nil
  def revoked_ttl_days do
    Application.get_env(@app, :jti_revoked_ttl_days)
  end

  @spec cleanup_interval_hours() :: integer() | nil
  def cleanup_interval_hours do
    Application.get_env(@app, :jti_revoked_cleanup_interval_hours)
  end
end
