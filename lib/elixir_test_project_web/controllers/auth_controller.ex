defmodule ElixirTestProjectWeb.AuthController do
  use ElixirTestProjectWeb, :controller

  alias ElixirTestProject.Users
  alias ElixirTestProjectWeb.Auth.Token
  require Logger

  # POST /api/auth/register
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
        user_map =
          user
          |> Map.from_struct()
          |> Map.drop([:__meta__, :password, :password_hash])
          |> Map.put(:id, user.id)

        json(conn, %{
          message: "User registered successfully",
          user: user_map
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  # POST /api/auth/login
  def login(conn, %{"phoneCode" => phone_code, "phone" => phone, "password" => password}) do
    case Users.get_user_by_phone(phone) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid phone or password"})

      user ->
        # Normalize and compare phone codes as strings to avoid type mismatches
        if to_string(user.phone_code) == to_string(phone_code) and
             Pbkdf2.verify_pass(password, user.password_hash) do
          # Use explicit signer so generation and verification use the same secret
          signer = Token.signer()

          user_map =
            user
            |> Map.from_struct()
            |> Map.drop([:__meta__, :password, :password_hash])
            |> Map.put(:id, user.id)

          # Convert atom keys to string keys for JWT claims (Joken expects binary keys)
          claims =
            user_map
            |> Enum.map(fn {k, v} -> {to_string(k), v} end)
            |> Enum.into(%{})

          case Token.generate_and_sign(Token.prepare_claims(claims), signer) do
            {:ok, jwt, _claims} ->
              json(conn, %{
                message: "Login successful",
                token: jwt,
                user: user_map
              })

            {:error, reason} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "token_generation_failed", reason: to_string(reason)})
          end
        else
          conn
          |> put_status(:unauthorized)
          |> json(%{error: "Invalid phone or password"})
        end
    end
  end

  # Fallback for missing or invalid params (e.g. wrong content-type)
  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "missing_params",
      message: "expected JSON body with \"phoneCode\", \"phone\" and \"password\""
    })
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end

  # GET /api/auth/verify-token
  # Only accepts Authorization header: Authorization: Bearer <token>
  def verify_token(conn, _params) do
    auth = get_req_header(conn, "authorization") |> List.first()

    case extract_bearer(auth) do
      {:ok, token} ->
        token = String.trim(token)

        # Try module-level verify first
        case safe_verify_module(token) do
          {:ok, claims} ->
            nclaims = Token.normalize_claims(claims)

            jti = Map.get(nclaims, "jti")

            if jti && Users.jti_revoked?(jti) do
              conn
              |> put_status(:unauthorized)
              |> json(%{valid: false, error: "token_revoked"})
            else
              json(conn, %{valid: true, claims: claims})
            end

          {:error, _} ->
            # Fallback to explicit signer(s)
            candidates =
              [
                System.get_env("JOKEN_SIGNING_SECRET"),
                Application.get_env(:elixir_test_project, ElixirTestProjectWeb.Endpoint)[
                  :secret_key_base
                ]
              ]
              |> Enum.filter(&(&1 not in [nil, ""]))
              |> Enum.uniq()
              |> Enum.map(&Joken.Signer.create("HS256", &1))

            case try_signers(token, candidates) do
              {:ok, claims} ->
                nclaims = Token.normalize_claims(claims)

                jti = Map.get(nclaims, "jti")

                if jti && Users.jti_revoked?(jti) do
                  conn
                  |> put_status(:unauthorized)
                  |> json(%{valid: false, error: "token_revoked"})
                else
                  json(conn, %{valid: true, claims: claims})
                end

              {:error, %Joken.Error{} = err} ->
                conn
                |> put_status(:unauthorized)
                |> json(%{valid: false, error: "invalid_token", reason: to_string(err)})

              {:error, reason} ->
                conn
                |> put_status(:unauthorized)
                |> json(%{valid: false, error: "invalid_token", reason: to_string(reason)})
            end
        end

      {:error, :no_authorization} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: "missing_authorization_header"})

      {:error, :invalid_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: "invalid_authorization_format"})
    end
  end

  # GET /api/auth/refresh-token
  # Reads Authorization: Bearer <token>, validates it, fetches fresh user from DB and returns a new token
  def refresh_token(conn, _params) do
    auth = get_req_header(conn, "authorization") |> List.first()

    case extract_bearer(auth) do
      {:ok, token} ->
        token = String.trim(token)

        case safe_verify_module(token) do
          {:ok, claims} ->
            nclaims = Token.normalize_claims(claims)

            jti = Map.get(nclaims, "jti")

            if jti && Users.jti_revoked?(jti) do
              conn
              |> put_status(:unauthorized)
              |> json(%{valid: false, error: "token_revoked"})
            else
              handle_refresh(conn, claims)
            end

          {:error, _} ->
            candidates =
              [
                System.get_env("JOKEN_SIGNING_SECRET"),
                Application.get_env(:elixir_test_project, ElixirTestProjectWeb.Endpoint)[
                  :secret_key_base
                ]
              ]
              |> Enum.filter(&(&1 not in [nil, ""]))
              |> Enum.uniq()
              |> Enum.map(&Joken.Signer.create("HS256", &1))

            case try_signers(token, candidates) do
              {:ok, claims} ->
                nclaims = Token.normalize_claims(claims)

                jti = Map.get(nclaims, "jti")

                if jti && Users.jti_revoked?(jti) do
                  conn
                  |> put_status(:unauthorized)
                  |> json(%{valid: false, error: "token_revoked"})
                else
                  handle_refresh(conn, claims)
                end

              {:error, _} ->
                conn
                |> put_status(:unauthorized)
                |> json(%{valid: false, error: "invalid_token"})
            end
        end

      {:error, :no_authorization} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: "missing_authorization_header"})

      {:error, :invalid_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{valid: false, error: "invalid_authorization_format"})
    end
  end

  defp handle_refresh(conn, claims) when is_map(claims) do
    # Accept several possible claim keys for user id
    user_id =
      Map.get(claims, "user_id") || Map.get(claims, :user_id) || Map.get(claims, "id") ||
        Map.get(claims, :id) || Map.get(claims, "sub")

    if is_nil(user_id) do
      conn
      |> put_status(:bad_request)
      |> json(%{error: "missing_user_id_in_token"})
    else
      case Users.get_user(user_id) do
        nil ->
          conn
          |> put_status(:not_found)
          |> json(%{error: "user_not_found"})

        user ->
          user_map =
            user
            |> Map.from_struct()
            |> Map.drop([:__meta__, :password, :password_hash])
            |> Map.put(:id, user.id)

          claims_for_token =
            user_map
            |> Enum.map(fn {k, v} -> {to_string(k), v} end)
            |> Enum.into(%{})

          signer = Token.signer()

          case Token.generate_and_sign(Token.prepare_claims(claims_for_token), signer) do
            {:ok, jwt, _} ->
              json(conn, %{message: "Token refreshed", token: jwt, user: user_map})

            {:error, reason} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "token_generation_failed", reason: to_string(reason)})
          end
      end
    end
  end

  defp safe_verify_module(token) do
    try do
      Token.verify_and_validate(token)
    rescue
      e in _ -> {:error, e}
    end
  end

  # POST /api/auth/logout
  # Expects Authorization: Bearer <token>. Revokes the token's JTI so it cannot be used again.
  def logout(conn, _params) do
    auth = get_req_header(conn, "authorization") |> List.first()

    case extract_bearer(auth) do
      {:ok, token} ->
        token = String.trim(token)

        case safe_verify_module(token) do
          {:ok, claims} when is_map(claims) ->
            jti = Map.get(claims, "jti") || Map.get(claims, :jti)
            user_id = Map.get(claims, "user_id") || Map.get(claims, :user_id)

            if is_nil(jti) do
              conn
              |> put_status(:bad_request)
              |> json(%{error: "missing_jti_in_token"})
            else
              case Users.revoke_jti(jti, user_id) do
                {:ok, _} ->
                  json(conn, %{logout: true})

                {:error, _} ->
                  conn
                  |> put_status(:internal_server_error)
                  |> json(%{logout: false, error: "logout_failed"})
              end
            end

          {:error, reason} ->
            # Log verification failure for debugging (do not log token)
            Logger.debug("logout: module verify failed: #{inspect(reason)}")
            # Fallback to explicit signer(s) used elsewhere (same as verify/refresh)
            candidates =
              [
                System.get_env("JOKEN_SIGNING_SECRET"),
                Application.get_env(:elixir_test_project, ElixirTestProjectWeb.Endpoint)[
                  :secret_key_base
                ]
              ]
              |> Enum.filter(&(&1 not in [nil, ""]))
              |> Enum.uniq()
              |> Enum.map(&Joken.Signer.create("HS256", &1))

            case try_signers(token, candidates) do
              {:ok, claims} when is_map(claims) ->
                jti = Map.get(claims, "jti") || Map.get(claims, :jti)
                user_id = Map.get(claims, "user_id") || Map.get(claims, :user_id)

                if is_nil(jti) do
                  conn
                  |> put_status(:bad_request)
                  |> json(%{logout: false, error: "missing_jti_in_token"})
                else
                  case Users.revoke_jti(jti, user_id) do
                    {:ok, _} ->
                      json(conn, %{logout: true})

                    {:error, _} ->
                      conn
                      |> put_status(:internal_server_error)
                      |> json(%{logout: false, error: "logout_failed"})
                  end
                end

              {:error, reason2} ->
                Logger.debug("logout: signer fallback failed: #{inspect(reason2)}")

                conn
                |> put_status(:unauthorized)
                |> json(%{logout: false, error: "invalid_token"})
            end
        end

      {:error, :no_authorization} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "missing_authorization_header"})

      {:error, :invalid_format} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "invalid_authorization_format"})
    end
  end

  defp try_signers(_token, []), do: {:error, "no_signers_available"}

  defp try_signers(token, [signer | rest]) do
    case Token.verify_and_validate(token, signer) do
      {:ok, claims} -> {:ok, claims}
      {:error, _} -> try_signers(token, rest)
    end
  end

  defp extract_bearer(nil), do: {:error, :no_authorization}
  defp extract_bearer(""), do: {:error, :no_authorization}

  defp extract_bearer("Bearer " <> token) when is_binary(token) and token != "" do
    {:ok, token}
  end

  defp extract_bearer(_), do: {:error, :invalid_format}
end
