defmodule ElixirTestProjectWeb.UsersController do
  use ElixirTestProjectWeb, :controller
  alias ElixirTestProject.Users
  alias ElixirTestProjectWeb.Auth.Token

  # POST /api/register
  def register(conn, %{
        "name" => name,
        "phone" => phone,
        "phoneCode" => phone_code,
        "password" => password
      }) do
    attrs = %{
      "name" => name,
      "phone" => phone,
      "phone_code" => phone_code,
      "password" => password
    }

    case Users.register_user(attrs) do
      {:ok, user} ->
        json(conn, %{
          message: "User registered successfully",
          user: %{id: user.id, phone: user.phone, name: user.name}
        })

      {:error, changeset} ->
        conn
        |> put_status(:bad_request)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  # POST /api/login
  def login(conn, %{"phoneCode" => phone_code, "phone" => phone, "password" => password}) do
    case Users.get_user_by_phone(phone) do
      nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid phone or password"})

      user ->
        # Normalize and compare phone codes as strings to avoid type mismatches
        if to_string(user.phone_code) == to_string(phone_code) and
             Pbkdf2.verify_pass(password, user.password_hash) do
          case Token.generate_and_sign(%{"user_id" => user.id}) do
            {:ok, jwt, _claims} ->
              json(conn, %{
                message: "Login successful",
                token: jwt,
                user: %{id: user.id, phone: user.phone, name: user.name}
              })

            {:error, reason} ->
              conn
              |> put_status(:internal_server_error)
              |> json(%{error: "token_generation_failed", reason: to_string(reason)})
          end
        else
          conn
          |> put_status(:unauthorized)
          |> json(%{error: "Invalid phone or password"})
        end
    end
  end

  # Fallback for missing or invalid params (e.g. wrong content-type)
  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "missing_params",
      message: "expected JSON body with \"phoneCode\", \"phone\" and \"password\""
    })
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
