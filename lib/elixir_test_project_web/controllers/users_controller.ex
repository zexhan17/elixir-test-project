defmodule ElixirTestProjectWeb.UsersController do
  use ElixirTestProjectWeb, :controller
  use OpenApiSpex.ControllerSpecs

  tags(["Users"])

  action_fallback ElixirTestProjectWeb.FallbackController

  alias ElixirTestProjectWeb.ApiSchemas

  @profile_response_fields ~w(name city state country address)a

  operation(:update_profile,
    summary: "Update editable user profile fields",
    operation_id: "UserUpdateProfile",
    description:
      "Accepts any subset of the editable profile fields and updates the authenticated user's record.",
    request_body:
      {"Profile payload", "application/json", ApiSchemas.UpdateProfileRequest,
       examples: %{"default" => %{"value" => ApiSchemas.UpdateProfileRequest.schema().example}}},
    responses: %{
      200 => {"Profile updated", "application/json", ApiSchemas.UpdateProfileResponse},
      401 =>
        {"Unauthorized", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the caller does not include a valid bearer token."},
      422 =>
        {"Validation failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the submitted values fail validation."}
    },
    security: [%{"bearerAuth" => []}]
  )

  def update_profile(%{assigns: %{current_user: user}} = conn, params) when is_map(params) do
    with {:ok, updated_user} <- ElixirTestProject.Users.update_profile(user, params) do
      json(conn, %{
        success: true,
        message: "Profile updated successfully",
        profile: profile_payload(updated_user)
      })
    end
  end

  defp profile_payload(user) do
    user
    |> Map.take(@profile_response_fields)
  end
end
