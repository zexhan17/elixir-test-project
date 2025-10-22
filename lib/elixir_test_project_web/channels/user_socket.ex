defmodule ElixirTestProjectWeb.UserSocket do
  use Phoenix.Socket
  require Logger
  alias ElixirTestProjectWeb.Auth

  ## Channels
  channel "user_presence:*", ElixirTestProjectWeb.PresenceChannel
  # other channels...

  # Client should pass token in params: new Socket("/socket", {token: "..."})
  # or via Authorization header, but JS phoenix socket easier with params.
  def connect(%{"token" => token} = _params, socket, _connect_info) when is_binary(token) do
    token = String.trim(token)

    case Auth.verify_and_fetch_user(token) do
      {:ok, user, claims} ->
        socket =
          socket
          |> assign(:current_user, user)
          |> assign(:token_claims, claims)
          |> assign(:token_jti, Map.get(claims, "jti"))

        {:ok, socket}

      {:error, reason} ->
        Logger.debug("socket authentication failed: #{inspect(reason)}")
        :error
    end
  end

  def connect(_, _socket, _connect_info), do: :error

  def id(_socket), do: nil
  # If you want to identify sockets per user:
  # def id(socket), do: "user_socket:#{socket.assigns.current_user.id}"
end
