defmodule ElixirTestProjectWeb.Plugs.AuthenticateUserPlug do
  @moduledoc """
  Plug to read Authorization header, validate a JWT and assign the current user to
  `conn.assigns.current_user`.

  The plug is non-fatal: if no token is present or verification fails, it will set
  `:current_user` to nil and continue. Controllers can choose to enforce authentication.
  """

  import Plug.Conn

  alias ElixirTestProjectWeb.Auth

  def init(opts), do: opts

  def call(conn, _opts) do
    auth_header = conn |> get_req_header("authorization") |> List.first()

    with {:ok, token} <- Auth.bearer_from_authorization(auth_header),
         {:ok, user, claims} <- Auth.verify_and_fetch_user(token) do
      conn
      |> assign(:current_user, user)
      |> assign(:token_claims, claims)
    else
      _ ->
        conn
        |> assign(:current_user, nil)
        |> assign(:token_claims, nil)
    end
  end
end
