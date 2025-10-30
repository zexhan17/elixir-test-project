defmodule ElixirTestProjectWeb.Auth.UserFetcher do
  @moduledoc """
  Helper to ensure fresh user data is returned in authentication endpoints.
  """
  alias ElixirTestProject.Users

  def refresh_user(%{id: user_id}) when is_binary(user_id) do
    case Users.get_user(user_id) do
      nil -> {:error, :user_not_found}
      user -> {:ok, user}
    end
  end

  def refresh_user(_), do: {:error, :invalid_user}
end
