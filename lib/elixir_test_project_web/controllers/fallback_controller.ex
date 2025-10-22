defmodule ElixirTestProjectWeb.FallbackController do
  @moduledoc """
  Ensures all controller errors return consistent JSON responses.
  Used with `action_fallback ElixirTestProjectWeb.FallbackController`.
  """
  use ElixirTestProjectWeb, :controller
  require Logger

  # Handle validation errors (Ecto changeset)
  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_failed", details: errors})
  end

  # Handle not found errors
  def call(conn, {:error, :not_found}) do
    conn
    |> put_status(:not_found)
    |> json(%{error: "not_found"})
  end

  # Handle unauthorized or forbidden cases
  def call(conn, {:error, :unauthorized}) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "unauthorized"})
  end

  def call(conn, {:error, :forbidden}) do
    conn
    |> put_status(:forbidden)
    |> json(%{error: "forbidden"})
  end

  # Handle all other {:error, reason} tuples
  def call(conn, {:error, reason}) do
    Logger.error("Unhandled error: #{inspect(reason)}")

    conn
    |> put_status(:bad_request)
    |> json(%{error: inspect(reason)})
  end

  # Catch all other unexpected values
  def call(conn, other) do
    Logger.error("Unexpected fallback: #{inspect(other)}")

    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "unexpected_error", data: inspect(other)})
  end
end
