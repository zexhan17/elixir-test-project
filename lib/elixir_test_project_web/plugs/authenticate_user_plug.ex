defmodule ElixirTestProjectWeb.Plugs.AuthenticateUserPlug do
  @moduledoc """
  Plug to read Authorization header, validate a JWT and assign the current user to
  `conn.assigns.current_user`.

  The plug is non-fatal: if no token is present or verification fails, it will set
  `:current_user` to nil and continue. Controllers can choose to enforce authentication.
  """

  import Plug.Conn

  alias ElixirTestProject.Users
  alias ElixirTestProjectWeb.Auth.Token

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> get_req_header("authorization")
    |> List.first()
    |> extract_bearer()
    |> case do
      {:ok, token} when is_binary(token) and token != "" ->
        token = String.trim(token)

        case verify_token(token) do
          {:ok, claims} when is_map(claims) ->
            assign(conn, :current_user, user_from_claims(claims))

          {:error, _} ->
            # Try explicit signer used during generation as a pragmatic fallback
            signer =
              try do
                Token.signer()
              rescue
                _ -> nil
              end

            case signer do
              nil ->
                assign(conn, :current_user, nil)

              signer ->
                case Token.verify_and_validate(token, signer) do
                  {:ok, claims} when is_map(claims) ->
                    assign(conn, :current_user, user_from_claims(claims))

                  _ ->
                    assign(conn, :current_user, nil)
                end
            end

          _ ->
            assign(conn, :current_user, nil)
        end

      _ ->
        assign(conn, :current_user, nil)
    end
  end

  defp extract_bearer(nil), do: {:error, :no_authorization}
  defp extract_bearer(""), do: {:error, :no_authorization}
  defp extract_bearer("Bearer " <> token) when is_binary(token) and token != "", do: {:ok, token}
  defp extract_bearer(_), do: {:error, :invalid_format}

  defp verify_token(token) do
    # Try module-level verification first
    try do
      Token.verify_and_validate(token)
    rescue
      _e ->
        # Fallback to trying potential signers (same approach as controller)
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

        try_signers(token, candidates)
    end
  end

  defp try_signers(_token, []), do: {:error, :no_signers_available}

  defp try_signers(token, [signer | rest]) do
    case Token.verify_and_validate(token, signer) do
      {:ok, claims} -> {:ok, claims}
      {:error, _} -> try_signers(token, rest)
    end
  end

  defp user_from_claims(claims) when is_map(claims) do
    user_id =
      Map.get(claims, "user_id") || Map.get(claims, :user_id) || Map.get(claims, "id") ||
        Map.get(claims, :id) || Map.get(claims, "sub")

    if user_id do
      Users.get_user(user_id)
    else
      nil
    end
  end

  defp user_from_claims(_), do: nil
end
