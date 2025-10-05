defmodule ElixirTestProjectWeb.UsersControllerTest do
  use ElixirTestProjectWeb.ConnCase, async: true

  alias ElixirTestProject.Users
  alias ElixirTestProject.Repo

  @valid_attrs %{
    "name" => "Test User",
    "phone" => "1234567890",
    "phoneCode" => "+1",
    "password" => "supersecret1"
  }
  @short_password %{
    "name" => "Short",
    "phone" => "1112223333",
    "phoneCode" => "+1",
    "password" => "short"
  }

  describe "POST /api/register" do
    test "registers a user and returns success and user", %{conn: conn} do
      conn = post(conn, "/api/register", @valid_attrs)
      assert json_response(conn, 200)["message"] == "User registered successfully"
      body = json_response(conn, 200)
      assert %{"user" => user_map} = body
      assert user_map["phone"] == @valid_attrs["phone"]

      # persisted in DB
      assert Users.get_user_by_phone(@valid_attrs["phone"]) != nil
    end

    test "returns validation errors for bad input", %{conn: conn} do
      conn = post(conn, "/api/register", @short_password)
      assert json_response(conn, 400)["errors"]
    end
  end

  describe "POST /api/login" do
    setup do
      # ensure a user exists to authenticate against
      # convert phoneCode => phone_code for the context
      attrs = %{
        "name" => @valid_attrs["name"],
        "phone" => @valid_attrs["phone"],
        "phone_code" => @valid_attrs["phoneCode"],
        "password" => @valid_attrs["password"]
      }

      {:ok, user} = Users.register_user(attrs)
      %{user: user}
    end

    test "login with correct credentials returns token and user", %{conn: conn} do
      login_payload = %{
        "phoneCode" => @valid_attrs["phoneCode"],
        "phone" => @valid_attrs["phone"],
        "password" => @valid_attrs["password"]
      }

      conn = post(conn, "/api/login", login_payload)
      assert json_response(conn, 200)["message"] == "Login successful"
      body = json_response(conn, 200)
      assert %{"token" => token, "user" => user_map} = body
      assert is_binary(token)
      assert user_map["phone"] == @valid_attrs["phone"]
    end

    test "login with invalid credentials returns 401", %{conn: conn} do
      conn =
        post(conn, "/api/login", %{
          "phoneCode" => @valid_attrs["phoneCode"],
          "phone" => @valid_attrs["phone"],
          "password" => "wrong"
        })

      assert response(conn, 401)
    end

    test "login missing params returns 400", %{conn: conn} do
      conn = post(conn, "/api/login", %{})
      assert json_response(conn, 400)["error"] == "missing_params"
    end
  end
end
