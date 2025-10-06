defmodule ElixirTestProjectWeb.Plugs.AuthenticateUserPlugTest do
  use ElixirTestProjectWeb.ConnCase, async: true

  alias ElixirTestProject.Users

  @valid_attrs %{
    "name" => "Plug User",
    "phone" => "9998887777",
    "phone_code" => "+1",
    "password" => "plugpass123"
  }

  test "assigns current_user when Authorization header contains valid token", %{conn: conn} do
    # create user and obtain token via login flow
    {:ok, user} = Users.register_user(@valid_attrs)

    login_payload = %{
      "phoneCode" => @valid_attrs["phone_code"] || @valid_attrs["phone_code"],
      "phone" => @valid_attrs["phone"],
      "password" => @valid_attrs["password"]
    }

    # use build_conn to call login and extract token
    token_conn =
      Phoenix.ConnTest.build_conn()
      |> post("/api/auth/login", %{
        "phoneCode" => "+1",
        "phone" => @valid_attrs["phone"],
        "password" => @valid_attrs["password"]
      })

    body = json_response(token_conn, 200)
    token = body["token"]
    assert is_binary(token)

    conn =
      conn
      |> put_req_header("authorization", "Bearer " <> token)

    conn = ElixirTestProjectWeb.Plugs.AuthenticateUserPlug.call(conn, %{})

    assert conn.assigns.current_user != nil
    assert conn.assigns.current_user.id == user.id
  end

  test "leaves current_user nil when no Authorization header present", %{conn: conn} do
    conn = ElixirTestProjectWeb.Plugs.AuthenticateUserPlug.call(conn, %{})
    assert conn.assigns.current_user == nil
  end
end
