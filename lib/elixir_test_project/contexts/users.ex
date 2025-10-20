defmodule ElixirTestProject.Users do
  @moduledoc """
  Users context: registration and authentication helpers.

  This module contains the core user lookup and authentication helpers used by
  controllers and plugs. It also provides a small API to record and query
  revoked JWT IDs (JTIs).
  """

  import Ecto.Query, warn: false
  alias ElixirTestProject.Repo
  alias ElixirTestProjectWeb.Presence
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

  # Marks a user online/offline in DB (simple boolean + timestamp pattern)
  def mark_user_online(user_id, is_online) when is_integer(user_id) or is_binary(user_id) do
    user_id = user_id
    user = get_user(user_id)

    if user do
      changeset =
        User.changeset(user, %{
          online: is_online,
          last_online_at: if(is_online, do: nil, else: DateTime.utc_now())
        })

      Repo.update(changeset)
    else
      {:error, :not_found}
    end
  end

  # Called on terminate — will check Presence for remaining presences and mark offline only if none remain.
  def maybe_mark_user_offline_after_disconnect(user_id) do
    topic = "user_presence:global"

    presences = Presence.list(topic)

    # presences is map keyed by presence key: e.g. "user:123" => %{metas: [...]}
    key = "user:#{user_id}"

    case Map.get(presences, key) do
      nil ->
        # no remaining presence entries for this user -> mark offline
        mark_user_online(user_id, false)

      %{metas: metas} when is_list(metas) and length(metas) == 0 ->
        mark_user_online(user_id, false)

      _ ->
        # still present on another socket/tab — keep online
        {:ok, :still_present}
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
