defmodule ElixirTestProjectWeb.ApiSpec do
  @moduledoc """
  Generates the OpenAPI specification for all HTTP endpoints.
  """

  @behaviour OpenApiSpex.OpenApi

  alias OpenApiSpex.{Components, Info, OpenApi, Paths, SecurityScheme, Server}

  @impl OpenApiSpex.OpenApi
  def spec do
    %OpenApi{
      info: %Info{
        title: "Elixir Test Project API",
        description:
          "Comprehensive reference for authentication, user profile management and media handling endpoints.",
        version: "1.0.0"
      },
      servers: [Server.from_endpoint(ElixirTestProjectWeb.Endpoint)],
      paths: Paths.from_router(ElixirTestProjectWeb.Router),
      components: %Components{
        securitySchemes: %{
          "bearerAuth" => %SecurityScheme{
            type: :http,
            scheme: "bearer",
            bearerFormat: "JWT",
            description:
              "Provide the JWT issued by the login endpoint as `Authorization: Bearer <token>`."
          }
        }
      }
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
