defmodule ElixirTestProjectWeb.PresenceChannel do
  use Phoenix.Channel
  alias ElixirTestProjectWeb.Presence
  alias ElixirTestProject.Users
  require Logger

  # topic: "user_presence:global" or "user_presence:#{some_room}"
  def join("user_presence:global", _payload, socket) do
    user = socket.assigns.current_user

    if user do
      send(self(), :after_join)
      {:ok, %{message: "joined presence"}, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    user = socket.assigns.current_user

    meta = %{
      online_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      phx_ref: socket.ref,
      name: user.name,
      is_seller: user.is_seller
    }

    # track user presence: key by user id to collapse multiple tabs/devices if desired
    Presence.track(socket, "user:#{user.id}", meta)
    # mark user online in DB (optional)
    Users.mark_user_online(user.id, true)

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  # optional: handle explicit "logout" message from client to revoke token
  def handle_in("logout", _payload, socket) do
    jti = socket.assigns[:token_jti]
    user = socket.assigns.current_user

    if jti do
      case Users.revoke_jti(jti, user.id) do
        {:ok, _} ->
          # force disconnect by replying and closing socket
          push(socket, "logged_out", %{ok: true})
          {:stop, :normal, socket}

        {:error, _} ->
          {:reply, {:error, %{error: "logout_failed"}}, socket}
      end
    else
      {:reply, {:error, %{error: "no_jti"}}, socket}
    end
  end

  # clean up on socket terminate
  def terminate(_reason, socket) do
    # Presence will automatically remove tracked presences for this socket ref.
    # But we may want to mark the user offline if no presences remain.
    user = socket.assigns[:current_user]

    if user do
      # Delay check slightly? here we do a synchronous check: list presences
      # But terminate is called for each socket; we will check Presence.list on the topic.
      # It's possible multiple sockets exist (other tabs) so we only mark offline when none left.
      topic = "user_presence:global"
      _presences = Presence.list(topic)
      # Presence.list expects socket or topic; if using socket-based list in other places, adapt.
      # We'll delegate check to Users module to compute presence count:

      Users.maybe_mark_user_offline_after_disconnect(user.id)
    end

    :ok
  end
end
