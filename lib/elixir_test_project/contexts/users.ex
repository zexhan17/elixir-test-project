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
  alias ElixirTestProjectWeb.Presence

  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) when is_map(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @spec get_user_by_phone(String.t()) :: User.t() | nil
  def get_user_by_phone(phone) when is_binary(phone) do
    Repo.get_by(User, phone: phone)
  end

  def get_user_by_phone(_), do: nil

  @doc """
  Get a user by id. Returns nil if not found.
  """
  @spec get_user(Ecto.UUID.t() | binary()) :: User.t() | nil
  def get_user(id) when is_binary(id) do
    Repo.get(User, id)
  end

  def get_user(_), do: nil

  @spec authenticate_user(String.t(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid_credentials}
  def authenticate_user(phone_code, phone, password)
      when is_binary(phone_code) and is_binary(phone) and is_binary(password) do
    with %User{} = user <- get_user_by_phone(phone),
         true <- phone_codes_match?(user.phone_code, phone_code),
         true <- Pbkdf2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      _ -> {:error, :invalid_credentials}
    end
  end

  def authenticate_user(_, _, _), do: {:error, :invalid_credentials}

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

  @spec mark_user_online(Ecto.UUID.t() | binary(), boolean()) ::
          {:ok, User.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mark_user_online(user_id, is_online) when is_binary(user_id) or is_integer(user_id) do
    with %User{} = user <- get_user(user_id) do
      attrs = %{
        online: is_online,
        last_online_at: online_timestamp(is_online)
      }

      user
      |> User.status_changeset(attrs)
      |> Repo.update()
    else
      nil -> {:error, :not_found}
    end
  end

  def mark_user_online(_user_id, _), do: {:error, :not_found}

  @doc """
  Called on terminate — will check Presence for remaining presences and mark offline only if none remain.
  """
  @spec maybe_mark_user_offline_after_disconnect(Ecto.UUID.t() | binary()) ::
          {:ok, :still_present} | {:ok, User.t()} | {:error, term()}
  def maybe_mark_user_offline_after_disconnect(user_id) do
    case presence_count(user_id) do
      0 -> mark_user_online(user_id, false)
      _ -> {:ok, :still_present}
    end
  end

  @doc """
  Check if a JTI has been revoked. Returns true if revoked, false otherwise.
  """
  def jti_revoked?(jti) when is_binary(jti) do
    query = from rt in RevokedToken, where: rt.jti == ^jti, select: rt.id
    Repo.exists?(query)
  end

  defp phone_codes_match?(stored, provided) when is_binary(stored) and is_binary(provided) do
    String.trim_leading(to_string(stored), "+") ==
      String.trim_leading(to_string(provided), "+")
  end

  defp phone_codes_match?(_, _), do: false

  defp online_timestamp(true), do: nil
  defp online_timestamp(false), do: DateTime.utc_now()

  defp presence_count(user_id) do
    "user_presence:global"
    |> Presence.list()
    |> Map.get("user:#{user_id}")
    |> case do
      %{metas: metas} when is_list(metas) -> length(metas)
      _ -> 0
    end
  end
end
