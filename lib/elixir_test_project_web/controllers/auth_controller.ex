defmodule ElixirTestProjectWeb.AuthController do
  use ElixirTestProjectWeb, :controller

  action_fallback ElixirTestProjectWeb.FallbackController

  alias ElixirTestProject.Users
  alias ElixirTestProjectWeb.Auth
  alias ElixirTestProjectWeb.Auth.Token

  require Logger

  @doc """
  POST /api/auth/register
  """
  def register(conn, %{
        "name" => name,
        "phone" => phone,
        "phoneCode" => phone_code,
        "password" => password
      }) do
    attrs = %{
      "name" => name,
      "phone" => phone,
      "phone_code" => phone_code,
      "password" => password
    }

    case Users.register_user(attrs) do
      {:ok, user} ->
        json(conn, %{
          message: "User registered successfully",
          user: present_user(user)
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  @doc """
  POST /api/auth/login
  """
  def login(conn, %{
        "phoneCode" => phone_code,
        "phone" => phone,
        "password" => password
      }) do
    case Users.authenticate_user(phone_code, phone, password) do
      {:ok, user} ->
        with {:ok, token, _claims} <- issue_token(user) do
          json(conn, %{
            message: "Login successful",
            token: token,
            user: present_user(user)
          })
        else
          {:error, reason} ->
            Logger.error("token_generation_failed: #{inspect(reason)}")

            conn
            |> put_status(:internal_server_error)
            |> json(%{error: "token_generation_failed"})
        end

      {:error, :invalid_credentials} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid phone or password"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "missing_params",
      message: ~s(expected JSON body with "phoneCode", "phone" and "password")
    })
  end

  @doc """
  GET /api/auth/verify-token
  """
  def verify_token(conn, _params) do
    case bearer_token(conn) do
      {:ok, token} ->
        case Auth.verify_not_revoked(token) do
          {:ok, claims} ->
            json(conn, %{valid: true, claims: claims})

          {:error, :revoked} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{valid: false, error: "token_revoked"})

          {:error, reason} ->
            Logger.debug("verify_token failed: #{inspect(reason)}")

            conn
            |> put_status(:unauthorized)
            |> json(%{valid: false, error: "invalid_token"})
        end

      {:error, :missing_token} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: "missing_authorization_header"})

      {:error, :invalid_authorization_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: "invalid_authorization_format"})
    end
  end

  @doc """
  GET /api/auth/refresh-token
  """
  def refresh_token(conn, _params) do
    case bearer_token(conn) do
      {:ok, token} ->
        with {:ok, user, _claims} <- Auth.verify_and_fetch_user(token),
             {:ok, refreshed_token, _new_claims} <- issue_token(user) do
          json(conn, %{
            message: "Token refreshed",
            token: refreshed_token,
            user: present_user(user)
          })
        else
          {:error, :revoked} ->
            conn
            |> put_status(:unauthorized)
            |> json(%{valid: false, error: "token_revoked"})

          {:error, reason} ->
            Logger.debug("refresh_token failed: #{inspect(reason)}")

            conn
            |> put_status(:unauthorized)
            |> json(%{valid: false, error: "invalid_token"})
        end

      {:error, :missing_token} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: "missing_authorization_header"})

      {:error, :invalid_authorization_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: "invalid_authorization_format"})
    end
  end

  @doc """
  POST /api/auth/logout
  """
  def logout(conn, _params) do
    case bearer_token(conn) do
      {:ok, token} ->
        with {:ok, claims} <- Auth.verify(token),
             {:ok, jti} <- jti_from_claims(claims),
             user_id <- Token.user_id_from_claims(claims),
             {:ok, _} <- Users.revoke_jti(jti, user_id) do
          json(conn, %{logout: true})
        else
          {:error, :missing_jti} ->
            conn
            |> put_status(:bad_request)
            |> json(%{logout: false, error: "missing_jti_in_token"})

          {:error, %Ecto.Changeset{} = changeset} ->
            Logger.error("logout changeset failure: #{inspect(changeset)}")

            conn
            |> put_status(:internal_server_error)
            |> json(%{logout: false, error: "logout_failed"})

          {:error, reason} ->
            Logger.debug("logout failed: #{inspect(reason)}")

            conn
            |> put_status(:unauthorized)
            |> json(%{logout: false, error: "invalid_token"})
        end

      {:error, :missing_token} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "missing_authorization_header"})

      {:error, :invalid_authorization_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_authorization_format"})
    end
  end

  defp bearer_token(conn) do
    conn
    |> get_req_header("authorization")
    |> List.first()
    |> Auth.bearer_from_authorization()
  end

  defp issue_token(user) do
    with {:ok, signer} <- runtime_signer(),
         claims <- Token.prepare_claims(user_claims(user)),
         {:ok, jwt, _} <- Token.generate_and_sign(claims, signer) do
      {:ok, jwt, claims}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp runtime_signer do
    {:ok, Token.signer()}
  rescue
    exception ->
      {:error, exception}
  end

  defp jti_from_claims(%{"jti" => jti}) when is_binary(jti), do: {:ok, jti}
  defp jti_from_claims(%{jti: jti}) when is_binary(jti), do: {:ok, jti}
  defp jti_from_claims(_), do: {:error, :missing_jti}

  defp present_user(user) do
    user
    |> Map.from_struct()
    |> Map.drop([:__meta__, :password, :password_hash])
  end

  defp user_claims(user) do
    user
    |> present_user()
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Map.new()
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
