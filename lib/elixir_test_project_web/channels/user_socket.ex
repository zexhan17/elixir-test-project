defmodule ElixirTestProjectWeb.UserSocket do
  use Phoenix.Socket
  require Logger
  alias ElixirTestProjectWeb.Auth.Token
  alias ElixirTestProject.Users

  ## Channels
  channel "user_presence:*", ElixirTestProjectWeb.PresenceChannel
  # other channels...

  # Client should pass token in params: new Socket("/socket", {token: "..."})
  # or via Authorization header, but JS phoenix socket easier with params.
  def connect(%{"token" => token} = _params, socket, _connect_info) when is_binary(token) do
    token = String.trim(token)

    # Try module-level verify first:
    case safe_verify_module(token) do
      {:ok, claims} ->
        handle_verified(claims, socket)

      {:error, _} ->
        # fallback to explicit signers like your controllers do
        signers =
          [
            System.get_env("JOKEN_SIGNING_SECRET"),
            Application.get_env(:elixir_test_project, ElixirTestProjectWeb.Endpoint)[
              :secret_key_base
            ]
          ]
          |> Enum.filter(&(&1 not in [nil, ""]))
          |> Enum.uniq()
          |> Enum.map(&Joken.Signer.create("HS256", &1))

        try_signers(token, signers, socket)
    end
  end

  def connect(_, _socket, _connect_info), do: :error

  defp handle_verified(claims, socket) when is_map(claims) do
    nclaims = Token.normalize_claims(claims)

    # find user id from possible fields
    user_id =
      Map.get(nclaims, "user_id") || Map.get(nclaims, :user_id) ||
        Map.get(nclaims, "id") || Map.get(nclaims, "sub")

    # optionally check JTI revocation
    jti = Map.get(nclaims, "jti") || Map.get(nclaims, :jti)

    if jti && Users.jti_revoked?(jti) do
      :error
    else
      case Users.get_user(user_id) do
        nil ->
          :error

        user ->
          # assign current_user and jti so channels/terminate can use it
          socket =
            socket
            |> assign(:current_user, user)
            |> assign(:token_jti, jti)

          {:ok, socket}
      end
    end
  end

  defp safe_verify_module(token) do
    try do
      Token.verify_and_validate(token)
    rescue
      e -> {:error, e}
    end
  end

  defp try_signers(_token, [], _socket), do: :error

  defp try_signers(token, [signer | rest], socket) do
    case Token.verify_and_validate(token, signer) do
      {:ok, claims} -> handle_verified(claims, socket)
      {:error, _} -> try_signers(token, rest, socket)
    end
  end

  def id(_socket), do: nil
  # If you want to identify sockets per user:
  # def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
