defmodule ElixirTestProject.RevokedTokenCleaner do
  @moduledoc """
  Periodically prune old revoked token records from the database.

  The TTL (in days) is configurable via the JTI_REVOKED_TTL_DAYS environment
  variable. If absent or invalid, defaults to 30 days. The cleanup job runs
  at a configured interval (default: every 24 hours). This module is intended
  to be started under the application's supervision tree.
  """

  use GenServer
  require Logger
  import Ecto.Query, warn: false

  alias ElixirTestProject.Repo
  alias ElixirTestProject.Schemas.RevokedToken

  # Defaults are provided by Auth.Config; module attributes removed to avoid
  # stale/unused warnings.

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_next()
    {:ok, state}
  end

  @impl true
  def handle_info(:cleanup, state) do
    case prune_old_revoked_tokens() do
      :ok -> :ok
      {:error, reason} -> Logger.error("RevokedTokenCleaner cleanup failed: #{inspect(reason)}")
    end

    schedule_next()
    {:noreply, state}
  end

  defp schedule_next do
    interval = cleanup_interval_ms()
    Process.send_after(self(), :cleanup, interval)
  end

  @spec cleanup_interval_ms() :: non_neg_integer()
  defp cleanup_interval_ms do
    hours = ElixirTestProjectWeb.Auth.Config.cleanup_interval_hours()
    max(hours, 1) * 60 * 60 * 1000
  end

  defp prune_old_revoked_tokens do
    ttl_days = ElixirTestProjectWeb.Auth.Config.revoked_ttl_days()
    cutoff = DateTime.utc_now() |> DateTime.add(-ttl_days * 24 * 60 * 60, :second)

    deleted =
      from(rt in RevokedToken, where: rt.inserted_at < ^cutoff)
      |> Repo.delete_all()
      |> elem(0)

    Logger.info("RevokedTokenCleaner removed #{deleted} revoked token(s)")
    :ok
  rescue
    exception ->
      Logger.error("""
      RevokedTokenCleaner encountered #{Exception.message(exception)}
      #{Exception.format(:error, exception, __STACKTRACE__)}
      """)

      {:error, exception}
  end
end
