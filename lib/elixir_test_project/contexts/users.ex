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
  require Logger

  @profile_fields ~w(name city state country address)a

  @doc """
  Registers a new user with the provided attributes.

  Returns the inserted `User` on success or an error changeset otherwise.
  """
  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) when is_map(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
    |> log_registration_result()
  end

  @doc """
  Retrieves a user by phone number.
  """
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

  @doc """
  Updates user profile fields (name, city, state, country, address) with sanitized input.
  """
  @spec update_profile(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_profile(%User{} = user, attrs) when is_map(attrs) do
    sanitized_attrs = sanitize_profile_attrs(attrs)

    user
    |> User.profile_changeset(sanitized_attrs)
    |> Repo.update()
  end

  def update_profile(_, _), do: {:error, :invalid_params}

  @doc """
  Authenticates a user by phone number and password.

  Returns `{:ok, user}` on success or `{:error, :invalid_credentials}` when authentication fails.
  """
  @spec authenticate_user(String.t(), String.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid_credentials}
  def authenticate_user(phone_code, phone, password)
      when is_binary(phone_code) and is_binary(phone) and is_binary(password) do
    with %User{} = user <- get_user_by_phone(phone),
         true <- phone_codes_match?(user.phone_code, phone_code),
         true <- Pbkdf2.verify_pass(password, user.password_hash) do
      {:ok, user}
    else
      _ ->
        Logger.warning("Authentication failed for provided credentials",
          phone: masked_phone(phone)
        )

        {:error, :invalid_credentials}
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
      {:ok, rt} ->
        Logger.info("Recorded revoked token", jti: jti, user_id: user_id)
        {:ok, rt}

      {:error, cs} ->
        Logger.error("Failed to record revoked token", jti: jti, errors: inspect(cs.errors))
        {:error, cs}

      other ->
        other
    end
  end

  @doc """
  Marks the given user as online or offline and updates the timestamp accordingly.
  """
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
      |> case do
        {:ok, updated} = result ->
          Logger.info("Updated user online status",
            user_id: updated.id,
            online: is_online
          )

          result

        {:error, changeset} = error ->
          Logger.error("Failed to update user online status",
            user_id: user_id,
            errors: inspect(changeset.errors)
          )

          error
      end
    else
      nil ->
        Logger.warning("Attempted to change status for missing user", user_id: user_id)
        {:error, :not_found}
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

  defp log_registration_result({:ok, %User{} = user} = result) do
    Logger.info("Registered new user", user_id: user.id)
    result
  end

  defp log_registration_result({:error, %Ecto.Changeset{} = changeset} = result) do
    Logger.warning("User registration failed", errors: inspect(changeset.errors))
    result
  end

  defp log_registration_result(result), do: result

  defp masked_phone(phone) when is_binary(phone) and byte_size(phone) > 4 do
    suffix = String.slice(phone, -4, 4)
    "****" <> suffix
  end

  defp masked_phone(phone), do: phone

  defp presence_count(user_id) do
    "user_presence:global"
    |> Presence.list()
    |> Map.get("user:#{user_id}")
    |> case do
      %{metas: metas} when is_list(metas) -> length(metas)
      _ -> 0
    end
  end

  defp sanitize_profile_attrs(attrs) when is_map(attrs) do
    Enum.reduce(@profile_fields, %{}, fn field, acc ->
      case fetch_profile_field(attrs, field) do
        :error ->
          acc

        {:ok, value} ->
          Map.put(acc, field, normalize_profile_value(value))
      end
    end)
  end

  defp fetch_profile_field(attrs, field) when is_map(attrs) and is_atom(field) do
    case Map.fetch(attrs, field) do
      {:ok, _} = result ->
        result

      :error ->
        attrs
        |> Map.fetch(Atom.to_string(field))
    end
  end

  defp fetch_profile_field(_, _), do: :error

  defp normalize_profile_value(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp normalize_profile_value(value) when is_integer(value) or is_float(value) do
    value
    |> to_string()
    |> normalize_profile_value()
  end

  defp normalize_profile_value(nil), do: nil
  defp normalize_profile_value(value), do: value
end
