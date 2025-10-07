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
    prune_old_revoked_tokens()
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
    hours * 60 * 60 * 1000
  end

  @spec ttl_days() :: pos_integer()
  defp ttl_days do
    ElixirTestProjectWeb.Auth.Config.revoked_ttl_days()
  end

  defp prune_old_revoked_tokens do
    cutoff = DateTime.utc_now() |> DateTime.add(-ttl_days() * 24 * 60 * 60, :second)

    {deleted, _} =
      from(rt in RevokedToken, where: rt.inserted_at < ^cutoff)
      |> Repo.delete_all()

    Logger.debug("RevokedTokenCleaner removed #{deleted} old revoked tokens")
  rescue
    e -> Logger.error("RevokedTokenCleaner failed: #{inspect(e)}")
  end
end
