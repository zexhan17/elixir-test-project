defmodule ElixirTestProjectWeb.GigCategoryController do
  use ElixirTestProjectWeb, :api_controller
  use OpenApiSpex.ControllerSpecs

  alias ElixirTestProject.Gigs
  alias ElixirTestProjectWeb.ApiSchemas
  alias OpenApiSpex.{Operation, Schema}

  tags(["Gigs"])

  operation(:index,
    operation_id: "GigCategoryIndex",
    summary: "List gig categories",
    description: "Returns all gig categories available for classifying gigs.",
    responses: %{
      200 => {"Categories list", "application/json", ApiSchemas.GigCategoryListResponse}
    }
  )

  def index(conn, _params) do
    categories =
      Gigs.list_categories()
      |> Enum.map(&category_json/1)

    json(conn, %{success: true, categories: categories})
  end

  operation(:create,
    operation_id: "GigCategoryCreate",
    summary: "Create a gig category",
    description: "Creates a new gig category using a unique key and human friendly label.",
    request_body:
      {"Category payload", "application/json", ApiSchemas.GigCategoryRequest,
       examples: %{
         "default" => %{"value" => ApiSchemas.GigCategoryRequest.schema().example}
       }},
    responses: %{
      201 => {"Category created", "application/json", ApiSchemas.GigCategoryResponse},
      422 =>
        {"Validation failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when validation fails."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def create(conn, params) do
    attrs = Map.take(params, ["key", "label", "description"])

    with {:ok, category} <- Gigs.create_category(attrs) do
      conn
      |> put_status(:created)
      |> json(%{success: true, category: category_json(category)})
    end
  end

  operation(:update,
    operation_id: "GigCategoryUpdate",
    summary: "Update a gig category",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: "uuid"},
        "Category ID",
        required: true
      )
    ],
    request_body:
      {"Category payload", "application/json", ApiSchemas.GigCategoryRequest,
       examples: %{
         "default" => %{"value" => ApiSchemas.GigCategoryRequest.schema().example}
       }},
    responses: %{
      200 => {"Category updated", "application/json", ApiSchemas.GigCategoryResponse},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the category ID does not exist."},
      422 =>
        {"Validation failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when validation fails."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def update(conn, %{"id" => id} = params) do
    attrs = Map.take(params, ["key", "label", "description"])

    with {:ok, category} <- fetch_category(id),
         {:ok, category} <- Gigs.update_category(category, attrs) do
      json(conn, %{success: true, category: category_json(category)})
    end
  end

  operation(:delete,
    operation_id: "GigCategoryDelete",
    summary: "Delete a gig category",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: "uuid"},
        "Category ID",
        required: true
      )
    ],
    responses: %{
      204 => {"Category deleted", "application/json", nil},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the category is missing."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, category} <- fetch_category(id),
         {:ok, _} <- Gigs.delete_category(category) do
      send_resp(conn, :no_content, "")
    end
  end

  defp fetch_category(id) do
    case Gigs.get_category(id) do
      %{} = category -> {:ok, category}
      _ -> {:error, :not_found}
    end
  end

  defp category_json(category) do
    %{
      id: category.id,
      key: category.key,
      label: category.label,
      description: category.description,
      inserted_at: category.inserted_at,
      updated_at: category.updated_at
    }
  end
end
