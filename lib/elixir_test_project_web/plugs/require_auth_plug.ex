defmodule ElixirTestProjectWeb.Plugs.RequireAuthPlug do
  @moduledoc """
  Plug that enforces an authenticated user. It expects
  `conn.assigns.current_user` to be set (by AuthenticateUserPlug).

  If no current_user is present, it returns HTTP 401 with a JSON body
  {"error": "unauthorized"} and halts the connection.
  """

  import Plug.Conn
  alias Phoenix.Controller

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> Controller.json(%{error: "unauthorized"})
        |> halt()

      _user ->
        conn
    end
  end
end
