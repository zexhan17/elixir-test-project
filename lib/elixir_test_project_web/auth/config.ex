defmodule ElixirTestProjectWeb.Auth.Config do
  @moduledoc """
  Centralized accessors for authentication-related configuration.

  These functions consult application config first (from `config/*.exs`) and
  fall back to environment variables for runtime overrides. Defaults are kept
  in `config/config.exs`.
  """

  @app :elixir_test_project

  @spec jwt_expires_days() :: pos_integer()
  def jwt_expires_days do
    case Application.get_env(@app, :joken_expires_time_in_days) do
      days when is_integer(days) and days > 0 ->
        days

      _ ->
        case System.get_env("JOKEN_EXPIRES_TIME_IN_DAYS") do
          nil ->
            1

          "" ->
            1

          val ->
            case Integer.parse(val) do
              {d, _} when d > 0 -> d
              _ -> 1
            end
        end
    end
  end

  @spec revoked_ttl_days() :: pos_integer()
  def revoked_ttl_days do
    case Application.get_env(@app, :jti_revoked_ttl_days) do
      d when is_integer(d) and d > 0 ->
        d

      _ ->
        case System.get_env("JTI_REVOKED_TTL_DAYS") do
          nil ->
            30

          "" ->
            30

          val ->
            case Integer.parse(val) do
              {d, _} when d > 0 -> d
              _ -> 30
            end
        end
    end
  end

  @spec cleanup_interval_hours() :: pos_integer()
  def cleanup_interval_hours do
    case Application.get_env(@app, :jti_revoked_cleanup_interval_hours) do
      h when is_integer(h) and h > 0 ->
        h

      _ ->
        case System.get_env("JTI_REVOKED_CLEANUP_INTERVAL_HOURS") do
          nil ->
            24

          "" ->
            24

          val ->
            case Integer.parse(val) do
              {h, _} when h > 0 -> h
              _ -> 24
            end
        end
    end
  end
end
