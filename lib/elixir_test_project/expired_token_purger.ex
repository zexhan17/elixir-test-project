defmodule ElixirTestProject.ExpiredTokenPurger do
  @moduledoc """
  Periodically removes expired revoked-token records from the database.

  This job runs every 6 hours and deletes revoked token records whose
  `inserted_at` is older than the configured TTL (via
  `ElixirTestProjectWeb.Auth.Config.revoked_ttl_days/0`).
  """

  use GenServer
  require Logger
  import Ecto.Query, warn: false

  alias ElixirTestProject.Repo
  alias ElixirTestProject.Schemas.RevokedToken

  @interval_ms 6 * 60 * 60 * 1000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    # Schedule immediate run and then regular interval
    send(self(), :run)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    run_once()
    Process.send_after(self(), :run, @interval_ms)
    {:noreply, state}
  end

  @spec run_once() :: :ok
  def run_once do
    ttl_days = ElixirTestProjectWeb.Auth.Config.revoked_ttl_days()
    cutoff = DateTime.utc_now() |> DateTime.add(-ttl_days * 24 * 60 * 60, :second)

    {deleted, _} =
      from(rt in RevokedToken, where: rt.inserted_at < ^cutoff)
      |> Repo.delete_all()

    Logger.info("ExpiredTokenPurger removed #{deleted} revoked token(s)")
    :ok
  rescue
    e ->
      Logger.error("ExpiredTokenPurger failed: #{inspect(e)}")
      :ok
  end
end
