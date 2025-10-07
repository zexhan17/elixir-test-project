defmodule ElixirTestProject.Users do
  @moduledoc """
  Users context: registration and authentication helpers.

  This module contains the core user lookup and authentication helpers used by
  controllers and plugs. It also provides a small API to record and query
  revoked JWT IDs (JTIs).
  """

  import Ecto.Query, warn: false
  alias ElixirTestProject.Repo
  alias ElixirTestProject.Schemas.User
  alias ElixirTestProject.Schemas.RevokedToken

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

  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  @spec get_user(Ecto.UUID.t() | binary()) :: User.t() | nil

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

  @doc """
  Revoke a token by JTI. Stores a RevokedToken record with revoked_at set to now.
  Returns {:ok, revoked_token} or {:error, changeset}.
  """
  def revoke_jti(jti, user_id \\ nil) when is_binary(jti) do
    params = %{
      "jti" => jti,
      "user_id" => user_id,
      "revoked_at" => DateTime.utc_now()
    }

    changeset = RevokedToken.changeset(%RevokedToken{}, params)

    case Repo.insert(changeset, on_conflict: :nothing) do
      {:ok, rt} -> {:ok, rt}
      {:error, cs} -> {:error, cs}
      other -> other
    end
  end

  @doc """
  Check if a JTI has been revoked. Returns true if revoked, false otherwise.
  """
  def jti_revoked?(jti) when is_binary(jti) do
    query = from rt in RevokedToken, where: rt.jti == ^jti, select: rt.id
    Repo.exists?(query)
  end
end
