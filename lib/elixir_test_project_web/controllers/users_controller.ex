defmodule ElixirTestProjectWeb.UsersController do
  use ElixirTestProjectWeb, :controller
  action_fallback ElixirTestProjectWeb.FallbackController

  @profile_response_fields ~w(name city state country address)a

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
