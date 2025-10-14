defmodule ElixirTestProjectWeb.ErrorController do
  use ElixirTestProjectWeb, :controller

  @doc """
  Handles unmatched API routes with JSON response.
  """
  def not_found(conn, _params) do
    conn
    |> put_status(:not_found)
    |> json(%{
      error: "not_found",
      message: "The requested resource could not be found"
    })
  end
end
