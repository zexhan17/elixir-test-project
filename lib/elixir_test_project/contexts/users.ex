defmodule ElixirTestProject.Users do
  @moduledoc """
  Users context: registration and authentication helpers.
  """

  import Ecto.Query, warn: false
  alias ElixirTestProject.Repo
  alias ElixirTestProject.Schemas.User

  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def get_user_by_phone(phone) do
    Repo.get_by(User, phone: phone)
  end

  @doc """
  Get a user by id. Returns nil if not found.
  """
  def get_user(id) do
    Repo.get(User, id)
  end

  def authenticate_user(phone, password) do
    case get_user_by_phone(phone) do
      nil ->
        {:error, :invalid_credentials}

      user ->
        if Pbkdf2.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end
    end
  end
end
