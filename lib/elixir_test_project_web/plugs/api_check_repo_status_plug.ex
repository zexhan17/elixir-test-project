defmodule ElixirTestProjectWeb.Plugs.ApiCheckRepoStatusPlug do
  @moduledoc """
  A small wrapper around `Phoenix.Ecto.CheckRepoStatus` that converts
  PendingMigrationError into a JSON response for API requests (paths
  starting with `/api`). This prevents the HTML debug page from being
  rendered in the browser for API endpoints when migrations are pending.
  """

  import Plug.Conn

  def init(opts), do: opts

  def call(conn, opts) do
    try do
      Phoenix.Ecto.CheckRepoStatus.call(conn, opts)
    rescue
      err in [Phoenix.Ecto.PendingMigrationError] ->
        if api_request?(conn) do
          body = %{
            error: "pending_migrations",
            message: Exception.message(err)
          }

          json = Phoenix.json_library().encode!(body)

          conn
          |> put_resp_content_type("application/json")
          |> send_resp(500, json)
          |> halt()
        else
          reraise err, __STACKTRACE__
        end
    end
  end

  defp api_request?(%Plug.Conn{request_path: path}) when is_binary(path) do
    String.starts_with?(path, "/api")
  end

  defp api_request?(_), do: false
end
