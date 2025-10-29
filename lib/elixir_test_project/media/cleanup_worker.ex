defmodule ElixirTestProject.Media.CleanupWorker do
  @moduledoc """
  Periodic worker that deletes unused media assets from storage and the database.
  """

  use GenServer

  require Logger

  alias ElixirTestProject.Media

  @cleanup_interval :timer.hours(24)
  @initial_delay :timer.minutes(5)

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @impl true
  def init(_opts) do
    schedule_cleanup(@initial_delay)
    {:ok, %{}}
  end

  @impl true
  def handle_info(:cleanup, state) do
    perform_cleanup()
    schedule_cleanup(@cleanup_interval)
    {:noreply, state}
  end

  defp perform_cleanup do
    %{deleted: deleted, failures: failures} = Media.cleanup_unused_media()

    if deleted > 0 do
      Logger.info("Media cleanup finished", deleted: deleted)
    end

    Enum.each(failures, fn failure ->
      Logger.error("Unable to delete unused media asset", asset_id: failure.id)
    end)

    %{deleted: deleted, failures: failures}
  end

  defp schedule_cleanup(interval) when is_integer(interval) and interval >= 0 do
    Process.send_after(self(), :cleanup, interval)
  end
end
