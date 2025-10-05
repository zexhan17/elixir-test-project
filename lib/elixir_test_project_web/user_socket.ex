defmodule ElixirTestProjectWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  # channel "room:*", ElixirTestProjectWeb.RoomChannel

  ## Transports
  # transport/2 is deprecated in recent Phoenix versions and will trigger a
  # deprecation warning. Comment it out if you don't use channels or re-enable
  # with the updated API if/when needed.
  # transport(:websocket, Phoenix.Transports.WebSocket)

  # If you need connect params, implement connect/3
  def connect(_params, socket, _connect_info) do
    {:ok, socket}
  end

  def id(_socket), do: nil
end
