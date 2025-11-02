defmodule ElixirTestProjectWeb.GigTypeController do
  use ElixirTestProjectWeb, :api_controller
  use OpenApiSpex.ControllerSpecs

  alias ElixirTestProject.Gigs
  alias ElixirTestProjectWeb.ApiSchemas
  alias OpenApiSpex.{Operation, Schema}

  tags(["Gigs"])

  operation(:index,
    operation_id: "GigTypeIndex",
    summary: "List gig types",
    description: "Returns gig types, optionally filtered by category ID.",
    parameters: [
      Operation.parameter(
        :category_id,
        :query,
        %Schema{type: :string, format: "uuid"},
        "Restrict results to this category ID",
        required: false
      )
    ],
    responses: %{
      200 => {"Gig types list", "application/json", ApiSchemas.GigTypeListResponse}
    }
  )

  def index(conn, params) do
    opts =
      case Map.get(params, "category_id") do
        nil -> []
        id -> [category_id: id]
      end

    types =
      Gigs.list_types(opts)
      |> Enum.map(&type_json/1)

    json(conn, %{success: true, types: types})
  end

  operation(:create,
    operation_id: "GigTypeCreate",
    summary: "Create a gig type",
    description: "Creates a new gig type associated with a category.",
    request_body:
      {"Type payload", "application/json", ApiSchemas.GigTypeRequest,
       examples: %{"default" => %{"value" => ApiSchemas.GigTypeRequest.schema().example}}},
    responses: %{
      201 => {"Gig type created", "application/json", ApiSchemas.GigTypeResponse},
      404 =>
        {"Category not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the provided category does not exist."},
      422 =>
        {"Validation failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when validation fails."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def create(conn, params) do
    attrs = Map.take(params, ["key", "label", "description", "category_id", "category_key"])

    with {:ok, type} <- Gigs.create_type(attrs) do
      conn
      |> put_status(:created)
      |> json(%{success: true, type: type_json(type)})
    end
  end

  operation(:update,
    operation_id: "GigTypeUpdate",
    summary: "Update a gig type",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: "uuid"},
        "Gig type ID",
        required: true
      )
    ],
    request_body:
      {"Type payload", "application/json", ApiSchemas.GigTypeRequest,
       examples: %{"default" => %{"value" => ApiSchemas.GigTypeRequest.schema().example}}},
    responses: %{
      200 => {"Gig type updated", "application/json", ApiSchemas.GigTypeResponse},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the gig type does not exist."},
      422 =>
        {"Validation failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when validation fails."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def update(conn, %{"id" => id} = params) do
    attrs = Map.take(params, ["key", "label", "description", "category_id", "category_key"])

    with {:ok, type} <- fetch_type(id),
         {:ok, type} <- Gigs.update_type(type, attrs) do
      json(conn, %{success: true, type: type_json(type)})
    end
  end

  operation(:delete,
    operation_id: "GigTypeDelete",
    summary: "Delete a gig type",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: "uuid"},
        "Gig type ID",
        required: true
      )
    ],
    responses: %{
      204 => {"Gig type deleted", "application/json", nil},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the gig type is missing."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, type} <- fetch_type(id),
         {:ok, _} <- Gigs.delete_type(type) do
      send_resp(conn, :no_content, "")
    end
  end

  defp fetch_type(id) do
    case Gigs.get_type(id) do
      %{} = type -> {:ok, type}
      _ -> {:error, :not_found}
    end
  end

  defp type_json(type) do
    %{
      id: type.id,
      key: type.key,
      label: type.label,
      description: type.description,
      category_id: type.category_id,
      inserted_at: type.inserted_at,
      updated_at: type.updated_at
    }
  end
end
