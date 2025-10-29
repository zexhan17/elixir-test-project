defmodule ElixirTestProjectWeb.HealthController do
  use ElixirTestProjectWeb, :controller
  use OpenApiSpex.ControllerSpecs

  tags(["Health"])

  action_fallback ElixirTestProjectWeb.FallbackController

  alias ElixirTestProjectWeb.ApiSchemas

  operation(:index,
    summary: "Service health probe",
    operation_id: "HealthCheck",
    description:
      "Simple readiness check that returns a plain-text confirmation when the API is online.",
    responses: %{
      200 => {"Health status", "text/plain", ApiSchemas.HealthResponse}
    }
  )

  def index(conn, _params) do
    text(conn, "server is running")
  end
end
