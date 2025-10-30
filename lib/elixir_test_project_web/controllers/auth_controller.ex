defmodule ElixirTestProjectWeb.AuthController do
  use ElixirTestProjectWeb, :controller
  use OpenApiSpex.ControllerSpecs

  tags(["Auth"])

  action_fallback ElixirTestProjectWeb.FallbackController

  alias ElixirTestProject.Users
  alias ElixirTestProjectWeb.Auth
  alias ElixirTestProjectWeb.Auth.Token
  alias ElixirTestProjectWeb.ApiSchemas

  require Logger

  operation(:register,
    summary: "Register a user account",
    operation_id: "AuthRegister",
    request_body:
      {"Registration payload", "application/json", ApiSchemas.RegisterRequest,
       examples: %{"default" => %{"value" => ApiSchemas.RegisterRequest.schema().example}}},
    responses: %{
      200 => {"Registration successful", "application/json", ApiSchemas.RegisterResponse},
      400 =>
        {"Registration failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when validation fails or the phone already exists."}
    },
    security: []
  )

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
      "phone" => normalize_phone(phone),
      "phone_code" => normalize_phone_code(phone_code),
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

  operation(:login,
    summary: "Authenticate and receive a JWT",
    operation_id: "AuthLogin",
    request_body:
      {"Login credentials", "application/json", ApiSchemas.LoginRequest,
       examples: %{"default" => %{"value" => ApiSchemas.LoginRequest.schema().example}}},
    responses: %{
      200 => {"Login successful", "application/json", ApiSchemas.LoginResponse},
      400 =>
        {"Missing parameters", "application/json", ApiSchemas.ErrorResponse,
         description:
           "Returned when the payload is missing required keys. The body includes an explanatory message."},
      401 =>
        {"Invalid credentials", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the phone or password does not match a user."}
    },
    security: []
  )

  @doc """
  POST /api/auth/login
  """
  def login(conn, %{
        "phoneCode" => phone_code,
        "phone" => phone,
        "password" => password
      }) do
    case Users.authenticate_user(
           normalize_phone_code(phone_code),
           normalize_phone(phone),
           password
         ) do
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

  operation(:verify_token,
    summary: "Validate a bearer token without refreshing it",
    operation_id: "AuthVerifyToken",
    responses: %{
      200 =>
        {"Token is valid", "application/json", ApiSchemas.VerifyTokenResponse,
         description: "Returns the decoded claims when the token is still valid."},
      400 =>
        {"Authorization header missing or malformed", "application/json",
         ApiSchemas.VerifyTokenResponse},
      401 => {"Token invalid or revoked", "application/json", ApiSchemas.VerifyTokenResponse}
    },
    security: [%{"bearerAuth" => []}]
  )

  @doc """
  GET /api/auth/verify-token
  """
  def verify_token(conn, _params) do
    case bearer_token(conn) do
      {:ok, token} ->
        case Auth.verify_and_fetch_user(token) do
          {:ok, user, claims} ->
            json(conn, %{
              valid: true,
              claims: claims,
              user: present_user(user)
            })

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

  operation(:refresh_token,
    summary: "Refresh a valid bearer token",
    operation_id: "AuthRefreshToken",
    responses: %{
      200 => {"Token refreshed", "application/json", ApiSchemas.RefreshTokenResponse},
      400 =>
        {"Authorization header missing or malformed", "application/json",
         ApiSchemas.VerifyTokenResponse},
      401 => {"Token invalid or revoked", "application/json", ApiSchemas.VerifyTokenResponse}
    },
    security: [%{"bearerAuth" => []}]
  )

  @doc """
  GET /api/auth/refresh-token
  """
  def refresh_token(conn, _params) do
    case bearer_token(conn) do
      {:ok, token} ->
        with {:ok, user, _claims} <- Auth.verify_and_fetch_user(token),
             {:ok, fresh_user} <- Auth.UserFetcher.refresh_user(user),
             {:ok, refreshed_token, _new_claims} <- issue_token(fresh_user) do
          json(conn, %{
            message: "Token refreshed",
            token: refreshed_token,
            user: present_user(fresh_user)
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

  operation(:logout,
    summary: "Revoke the current bearer token",
    operation_id: "AuthLogout",
    responses: %{
      200 => {"Logout success", "application/json", ApiSchemas.LogoutResponse},
      400 =>
        {"Missing token or claims", "application/json", ApiSchemas.LogoutResponse,
         description:
           "Returned when the Authorization header is missing or the token lacks a JTI."},
      401 =>
        {"Token invalid", "application/json", ApiSchemas.LogoutResponse,
         description: "Returned when the bearer token fails verification."}
    },
    security: [%{"bearerAuth" => []}]
  )

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

  defp normalize_phone(phone) when is_binary(phone), do: String.trim(phone)
  defp normalize_phone(phone) when is_integer(phone), do: Integer.to_string(phone)
  defp normalize_phone(phone) when is_float(phone), do: trunc(phone) |> Integer.to_string()
  defp normalize_phone(phone), do: to_string(phone)

  defp normalize_phone_code(phone_code) when is_binary(phone_code),
    do: phone_code |> String.trim() |> String.upcase()

  defp normalize_phone_code(phone_code), do: phone_code |> to_string() |> normalize_phone_code()

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
