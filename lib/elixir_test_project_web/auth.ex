defmodule ElixirTestProjectWeb.Auth do
  @moduledoc """
  High-level authentication helpers shared across controllers, plugs and sockets.

  This module centralises token verification, revocation checks and user lookups
  so individual components only need to deal with success/error tuples.
  """

  alias ElixirTestProject.Users
  alias ElixirTestProject.Schemas.User
  alias ElixirTestProjectWeb.Auth.Token

  @type token :: String.t()
  @type claims :: map()
  @type reason ::
          :missing_token
          | :invalid_token
          | :invalid_authorization_format
          | :revoked
          | :missing_user_id
          | :user_not_found
          | term()

  @spec verify(token()) :: {:ok, claims()} | {:error, reason()}
  def verify(token) when is_binary(token) do
    token
    |> String.trim()
    |> do_verify()
  end

  def verify(_token), do: {:error, :missing_token}

  @spec verify_not_revoked(token()) :: {:ok, claims()} | {:error, reason()}
  def verify_not_revoked(token) do
    with {:ok, claims} <- verify(token),
         false <- revoked?(claims) do
      {:ok, claims}
    else
      true -> {:error, :revoked}
      {:error, _} = error -> error
    end
  end

  @spec verify_and_fetch_user(token()) :: {:ok, User.t(), claims()} | {:error, reason()}
  def verify_and_fetch_user(token) do
    with {:ok, claims} <- verify_not_revoked(token),
         {:ok, user} <- fetch_user(claims) do
      {:ok, user, claims}
    end
  end

  @spec bearer_from_authorization(String.t() | nil) :: {:ok, token()} | {:error, reason()}
  def bearer_from_authorization(nil), do: {:error, :missing_token}
  def bearer_from_authorization(""), do: {:error, :missing_token}

  def bearer_from_authorization("Bearer " <> token) when is_binary(token) and token != "" do
    {:ok, token}
  end

  def bearer_from_authorization(_), do: {:error, :invalid_authorization_format}

  @spec fetch_user(claims()) :: {:ok, User.t()} | {:error, reason()}
  def fetch_user(claims) when is_map(claims) do
    case Token.user_id_from_claims(claims) do
      nil ->
        {:error, :missing_user_id}

      user_id ->
        case Users.get_user(user_id) do
          nil -> {:error, :user_not_found}
          user -> {:ok, user}
        end
    end
  end

  def fetch_user(_), do: {:error, :missing_user_id}

  @doc """
  Checks whether the provided claims map has a revoked JTI entry.
  """
  @spec revoked?(claims()) :: boolean()
  def revoked?(claims) when is_map(claims) do
    case Map.get(claims, "jti") || Map.get(claims, :jti) do
      nil -> false
      jti -> Users.jti_revoked?(jti)
    end
  end

  def revoked?(_), do: false

  defp do_verify(token) when token in [nil, ""], do: {:error, :missing_token}

  defp do_verify(token) do
    token
    |> try_default_signer()
    |> case do
      {:ok, claims} ->
        {:ok, claims}

      _ ->
        token
        |> try_runtime_signer()
        |> case do
          {:ok, claims} -> {:ok, claims}
          {:error, reason} -> {:error, reason}
        end
    end
  end

  defp try_default_signer(token) do
    safe_verify(fn -> Token.verify_and_validate(token) end)
  end

  defp try_runtime_signer(token) do
    case runtime_signers() do
      [] -> {:error, :invalid_token}
      signers -> try_signers(token, signers)
    end
  end

  defp runtime_signers do
    with {:ok, signer} <- build_runtime_signer() do
      [signer]
    else
      {:error, _} -> []
    end
  end

  defp build_runtime_signer do
    {:ok, Token.signer()}
  rescue
    exception -> {:error, exception}
  end

  defp try_signers(_token, []), do: {:error, :invalid_token}

  defp try_signers(token, [signer | rest]) do
    case safe_verify(fn -> Token.verify_and_validate(token, signer) end) do
      {:ok, claims} -> {:ok, claims}
      {:error, _} -> try_signers(token, rest)
    end
  end

  defp safe_verify(fun) when is_function(fun, 0) do
    case fun.() do
      {:ok, claims} ->
        {:ok, Token.normalize_claims(claims)}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    exception -> {:error, exception}
  end
end
