defmodule ElixirTestProjectWeb.UsersControllerTest do
  use ElixirTestProjectWeb.ConnCase, async: true

  alias ElixirTestProject.{Repo, Users}
  alias ElixirTestProject.Schemas.GoogleAuth

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
      conn = post(conn, "/api/auth/register", @valid_attrs)
      assert json_response(conn, 200)["message"] == "User registered successfully"
      body = json_response(conn, 200)
      assert %{"user" => user_map} = body
      assert user_map["phone"] == @valid_attrs["phone"]

      # persisted in DB
      assert Users.get_user_by_phone(@valid_attrs["phone"]) != nil
    end

    test "returns validation errors for bad input", %{conn: conn} do
      conn = post(conn, "/api/auth/register", @short_password)
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

      conn = post(conn, "/api/auth/login", login_payload)
      assert json_response(conn, 200)["message"] == "Login successful"
      body = json_response(conn, 200)
      assert %{"token" => token, "user" => user_map} = body
      assert is_binary(token)
      assert user_map["phone"] == @valid_attrs["phone"]
    end

    test "login with invalid credentials returns 401", %{conn: conn} do
      conn =
        post(conn, "/api/auth/login", %{
          "phoneCode" => @valid_attrs["phoneCode"],
          "phone" => @valid_attrs["phone"],
          "password" => "wrong"
        })

      assert response(conn, 401)
    end

    test "login missing params returns 400", %{conn: conn} do
      conn = post(conn, "/api/auth/login", %{})
      assert json_response(conn, 400)["error"] == "missing_params"
    end
  end

  describe "GET /api/verify-token and /api/refresh-token" do
    setup do
      attrs = %{
        "name" => @valid_attrs["name"],
        "phone" => @valid_attrs["phone"],
        "phone_code" => @valid_attrs["phoneCode"],
        "password" => @valid_attrs["password"]
      }

      {:ok, user} = Users.register_user(attrs)

      login_payload = %{
        "phoneCode" => @valid_attrs["phoneCode"],
        "phone" => @valid_attrs["phone"],
        "password" => @valid_attrs["password"]
      }

      # We use a conn built by ConnCase in tests
      token_conn =
        Phoenix.ConnTest.build_conn()
        |> post("/api/auth/login", login_payload)

      resp = json_response(token_conn, 200)
      token = resp["token"]

      %{token: token, user: user}
    end

    test "verify-token returns claims and is valid", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get("/api/auth/verify-token")

      assert json_response(conn, 200)["valid"] == true
      assert json_response(conn, 200)["claims"]
    end

    test "refresh-token returns a new token and user", %{conn: conn, token: token, user: user} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> get("/api/auth/refresh-token")

      body = json_response(conn, 200)
      assert body["message"] == "Token refreshed"
      assert is_binary(body["token"]) and byte_size(body["token"]) > 0
      assert body["user"]["phone"] == user.phone
    end
  end

  describe "POST /api/user/update-profile" do
    setup do
      attrs = %{
        "name" => "Profile User",
        "phone" => "9998887777",
        "phone_code" => @valid_attrs["phoneCode"],
        "password" => @valid_attrs["password"]
      }

      {:ok, user} = Users.register_user(attrs)

      login_payload = %{
        "phoneCode" => attrs["phone_code"],
        "phone" => attrs["phone"],
        "password" => attrs["password"]
      }

      token_conn =
        Phoenix.ConnTest.build_conn()
        |> post("/api/auth/login", login_payload)

      token = json_response(token_conn, 200)["token"]
      %{user: user, token: token}
    end

    test "updates profile with sanitized data", %{conn: conn, token: token, user: user} do
      payload = %{
        "name" => "Updated User",
        "city" => "  New York  ",
        "state" => "NY",
        "country" => "USA",
        "address" => "123 Market St"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> post("/api/user/update-profile", payload)

      body = json_response(conn, 200)
      assert body["success"] == true
      assert body["message"] == "Profile updated successfully"
      assert body["profile"]["city"] == "New York"

      updated = Users.get_user(user.id)
      assert updated.name == "Updated User"
      assert updated.city == "New York"
      assert updated.state == "NY"
      assert updated.country == "USA"
      assert updated.address == "123 Market St"
    end

    test "returns unauthorized without token", %{conn: conn} do
      conn = post(conn, "/api/user/update-profile", %{"name" => "No Auth"})
      assert json_response(conn, 401)["error"] == "Not authenticated"
    end

    test "returns validation errors for overly long fields", %{conn: conn, token: token} do
      long_address = String.duplicate("A", 260)
      payload = %{"address" => long_address}

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> post("/api/user/update-profile", payload)

      body = json_response(conn, 422)
      assert body["error"] == "validation_failed"
      assert body["details"]["address"] != []
    end
  end

  describe "POST /api/user/upload-image" do
    setup do
      attrs = %{
        "name" => "Drive User",
        "phone" => "2223334444",
        "phone_code" => @valid_attrs["phoneCode"],
        "password" => @valid_attrs["password"]
      }

      {:ok, user} = Users.register_user(attrs)

      login_payload = %{
        "phoneCode" => attrs["phone_code"],
        "phone" => attrs["phone"],
        "password" => attrs["password"]
      }

      token_conn =
        Phoenix.ConnTest.build_conn()
        |> post("/api/auth/login", login_payload)

      token = json_response(token_conn, 200)["token"]

      %GoogleAuth{}
      |> GoogleAuth.changeset(%{
        user_id: user.id,
        google_user_id: "google-user-#{System.unique_integer([:positive])}",
        access_token: "test-token",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second)
      })
      |> Repo.insert!()

      %{token: token, user: user}
    end

    test "returns bad_request when upload payload is invalid", %{conn: conn, token: token} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> post("/api/user/upload-image", %{"filename" => "photo.png", "file" => "invalid"})

      assert json_response(conn, 400)["error"] == "invalid_upload_payload"
    end

    test "returns error when file cannot be read", %{conn: conn, token: token} do
      missing_path =
        Path.join(System.tmp_dir!(), "nonexistent-#{System.unique_integer([:positive])}.png")

      upload = %Plug.Upload{
        path: missing_path,
        filename: "photo.png",
        content_type: "image/png"
      }

      conn =
        conn
        |> put_req_header("authorization", "Bearer " <> token)
        |> post("/api/user/upload-image", %{"filename" => "photo.png", "file" => upload})

      assert json_response(conn, 400)["error"] == "file_read_failed"
    end
  end
end
