defmodule ElixirTestProjectWeb.ErrorController do
  use ElixirTestProjectWeb, :controller
  use OpenApiSpex.ControllerSpecs

  tags(["Errors"])

  alias ElixirTestProjectWeb.ApiSchemas

  operation(:not_found,
    summary: "Catch-all for unknown API routes",
    operation_id: "ErrorCatchAll",
    responses: %{
      404 =>
        {"Route not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when no matching API route exists."}
    },
    security: []
  )

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
