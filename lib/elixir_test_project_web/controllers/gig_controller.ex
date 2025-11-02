defmodule ElixirTestProjectWeb.GigController do
  use ElixirTestProjectWeb, :api_controller
  use OpenApiSpex.ControllerSpecs

  alias ElixirTestProject.Gigs
  alias ElixirTestProjectWeb.ApiSchemas
  alias OpenApiSpex.{Operation, Schema}

  tags(["Gigs"])

  operation(:index,
    operation_id: "GigIndex",
    summary: "List gigs",
    description:
      "Returns gigs filtered by query parameters such as category, type, seller, delivery options or active status.",
    parameters: ApiSchemas.GigFilterParams.parameters(),
    responses: %{
      200 => {"Gig list", "application/json", ApiSchemas.GigListResponse}
    }
  )

  def index(conn, params) do
    gigs =
      params
      |> Map.drop(["page", "page_size"])
      |> Gigs.list_gigs()
      |> Enum.map(&gig_json/1)

    json(conn, %{success: true, gigs: gigs})
  end

  operation(:show,
    operation_id: "GigShow",
    summary: "Retrieve a single gig",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: :uuid},
        "Gig ID",
        required: true
      )
    ],
    responses: %{
      200 => {"Gig details", "application/json", ApiSchemas.GigResponse},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the gig does not exist."}
    }
  )

  def show(conn, %{"id" => id}) do
    with {:ok, gig} <- fetch_gig(id) do
      json(conn, %{success: true, gig: gig_json(gig)})
    end
  end

  operation(:create,
    operation_id: "GigCreate",
    summary: "Create a gig",
    request_body:
      {"Gig payload", "application/json", ApiSchemas.GigRequest,
       examples: %{"default" => %{"value" => ApiSchemas.GigRequest.schema().example}}},
    responses: %{
      201 => {"Gig created", "application/json", ApiSchemas.GigResponse},
      404 =>
        {"Reference missing", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the provided category or type cannot be found."},
      422 =>
        {"Validation failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when validation fails."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def create(conn, params) do
    with {:ok, gig} <- Gigs.create_gig(params) do
      conn
      |> put_status(:created)
      |> json(%{success: true, gig: gig_json(gig)})
    end
  end

  operation(:update,
    operation_id: "GigUpdate",
    summary: "Update a gig",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: :uuid},
        "Gig ID",
        required: true
      )
    ],
    request_body:
      {"Gig payload", "application/json", ApiSchemas.GigRequest,
       examples: %{"default" => %{"value" => ApiSchemas.GigRequest.schema().example}}},
    responses: %{
      200 => {"Gig updated", "application/json", ApiSchemas.GigResponse},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the gig does not exist."},
      422 =>
        {"Validation failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when validation fails."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def update(conn, %{"id" => id} = params) do
    params = Map.delete(params, "id")

    with {:ok, gig} <- fetch_gig(id),
         {:ok, gig} <- Gigs.update_gig(gig, params) do
      json(conn, %{success: true, gig: gig_json(gig)})
    end
  end

  operation(:delete,
    operation_id: "GigDelete",
    summary: "Delete a gig",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: :uuid},
        "Gig ID",
        required: true
      )
    ],
    responses: %{
      204 => {"Gig deleted", "application/json", nil},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the gig does not exist."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def delete(conn, %{"id" => id}) do
    with {:ok, gig} <- fetch_gig(id),
         {:ok, _gig} <- Gigs.delete_gig(gig) do
      send_resp(conn, :no_content, "")
    end
  end

  operation(:activate,
    operation_id: "GigActivate",
    summary: "Activate a gig",
    description: "Marks a gig as active and available.",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: :uuid},
        "Gig ID",
        required: true
      )
    ],
    responses: %{
      200 => {"Gig activated", "application/json", ApiSchemas.GigResponse},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the gig does not exist."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def activate(conn, %{"id" => id}) do
    with {:ok, gig} <- fetch_gig(id),
         {:ok, gig} <- Gigs.activate_gig(gig) do
      json(conn, %{success: true, gig: gig_json(gig)})
    end
  end

  operation(:deactivate,
    operation_id: "GigDeactivate",
    summary: "Deactivate a gig",
    description: "Marks a gig as inactive without deleting it.",
    parameters: [
      Operation.parameter(
        :id,
        :path,
        %Schema{type: :string, format: :uuid},
        "Gig ID",
        required: true
      )
    ],
    responses: %{
      200 => {"Gig deactivated", "application/json", ApiSchemas.GigResponse},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the gig does not exist."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def deactivate(conn, %{"id" => id}) do
    with {:ok, gig} <- fetch_gig(id),
         {:ok, gig} <- Gigs.deactivate_gig(gig) do
      json(conn, %{success: true, gig: gig_json(gig)})
    end
  end

  defp fetch_gig(id) do
    case Gigs.get_gig(id) do
      nil -> {:error, :not_found}
      _ -> {:ok, Gigs.get_gig!(id)}
    end
  end

  defp gig_json(gig) do
    %{
      id: gig.id,
      title: gig.title,
      description: gig.description,
      category: category_json(gig.category),
      type: type_json(gig.type),
      seller: %{
        name: gig.seller_name,
        role: to_list(gig.seller_roles),
        location: gig.seller_location
      },
      availability: %{
        days: gig.availability_days,
        timings: gig.availability_timings
      },
      order_limits: %{
        min: gig.order_min,
        max: gig.order_max
      },
      reviews: gig.reviews,
      review_count: gig.review_count,
      price: gig.price,
      delivery: %{
        available: gig.delivery_available,
        type: gig.delivery_type,
        areasCovered: to_list(gig.delivery_areas),
        radiusKm: gig.delivery_radius_km,
        charges: %{
          type: gig.delivery_charges_type,
          amount: gig.delivery_charges_amount,
          perKmAmount: gig.delivery_charges_per_km_amount,
          freeAbove: gig.delivery_charges_free_above
        }
      },
      subscription:
        if(gig.subscription_available || not is_nil(gig.subscription_type),
          do: %{
            available: gig.subscription_available,
            type: gig.subscription_type,
            description: gig.subscription_description,
            discountPercent: gig.subscription_discount_percent,
            pricePerMonth: gig.subscription_price_per_month,
            dailyQuantity: gig.subscription_daily_quantity,
            notes: gig.subscription_notes
          },
          else: nil
        ),
      extras: to_list(gig.extras),
      purity: gig.purity,
      is_active: gig.is_active,
      metadata: gig.metadata || %{},
      inserted_at: gig.inserted_at,
      updated_at: gig.updated_at
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  defp category_json(nil), do: nil

  defp category_json(category) do
    %{
      id: category.id,
      key: category.key,
      label: category.label
    }
  end

  defp type_json(nil), do: nil

  defp type_json(type) do
    %{
      id: type.id,
      key: type.key,
      label: type.label,
      category_id: type.category_id
    }
  end

  defp to_list(value) when is_list(value), do: Enum.map(value, &to_string/1)
  defp to_list(value) when is_binary(value), do: [value]
  defp to_list(_), do: []
end
