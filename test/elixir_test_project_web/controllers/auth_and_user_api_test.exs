defmodule ElixirTestProjectWeb.AuthAndUserApiTest do
  use ElixirTestProjectWeb.ConnCase, async: true

  alias ElixirTestProject.Users

  @valid_attrs %{
    "name" => "API User",
    "phone" => "5556667777",
    "phoneCode" => "+1",
    "password" => "apipass123"
  }

  test "full auth flow: register, login, verify, refresh, logout", %{conn: conn} do
    # Register
    conn = post(conn, "/api/auth/register", @valid_attrs)
    assert json_response(conn, 200)["message"] == "User registered successfully"

    # Login (use fresh conn)
    login_conn = Phoenix.ConnTest.build_conn()

    login_conn =
      post(login_conn, "/api/auth/login", %{
        "phoneCode" => @valid_attrs["phoneCode"],
        "phone" => @valid_attrs["phone"],
        "password" => @valid_attrs["password"]
      })

    body = json_response(login_conn, 200)
    assert body["message"] == "Login successful"
    token = body["token"]
    assert is_binary(token)

    # Verify
    verify_conn =
      Phoenix.ConnTest.build_conn() |> put_req_header("authorization", "Bearer " <> token)

    verify_conn = get(verify_conn, "/api/auth/verify-token")
    assert json_response(verify_conn, 200)["valid"] == true

    # Refresh
    refresh_conn =
      Phoenix.ConnTest.build_conn() |> put_req_header("authorization", "Bearer " <> token)

    refresh_conn = get(refresh_conn, "/api/auth/refresh-token")
    refreshed = json_response(refresh_conn, 200)
    assert refreshed["message"] == "Token refreshed"
    assert is_binary(refreshed["token"]) and byte_size(refreshed["token"]) > 0

    # Logout using refreshed token
    logout_conn =
      Phoenix.ConnTest.build_conn()
      |> put_req_header("authorization", "Bearer " <> refreshed["token"])
      |> post("/api/auth/logout", %{})

    assert json_response(logout_conn, 200)["logout"] == true
  end

  test "get-google-redirect-link returns URL when env present", %{conn: conn} do
    # Set env vars for the test
    System.put_env("GOOGLE_CLIENT_ID", "test-client-id")
    System.put_env("GOOGLE_CALLBACK_URL", "http://localhost:4000/auth/google/redirect")
    original_config = Application.get_env(:elixir_test_project, :google_oauth)

    Application.put_env(:elixir_test_project, :google_oauth, %{
      client_id: "test-client-id",
      client_secret: "test-client-secret",
      callback_url: "http://localhost:4000/auth/google/redirect"
    })

    on_exit(fn ->
      case original_config do
        nil -> Application.delete_env(:elixir_test_project, :google_oauth)
        config -> Application.put_env(:elixir_test_project, :google_oauth, config)
      end
    end)

    conn = get(conn, "/api/user/get-google-redirect-link")
    body = json_response(conn, 200)
    assert body["redirect_url"] =~ "accounts.google.com"
    assert body["redirect_url"] =~ "client_id=test-client-id"
  end
end
