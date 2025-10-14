defmodule ElixirTestProjectWeb.UsersController do
  use ElixirTestProjectWeb, :controller
  action_fallback ElixirTestProjectWeb.FallbackController
  alias ElixirTestProject.Google

  @google_oauth_base "https://accounts.google.com/o/oauth2/v2/auth"

  def get_google_redirect_link(conn, _params) do
    oauth_config = Application.get_env(:elixir_test_project, :google_oauth, [])
    client_id = oauth_config[:client_id]
    redirect_uri = oauth_config[:callback_url]

    scope =
      Enum.join(
        [
          "openid",
          "email",
          "profile",
          "https://www.googleapis.com/auth/drive.file"
        ],
        " "
      )

    params = %{
      client_id: client_id,
      redirect_uri: redirect_uri,
      response_type: "code",
      scope: scope,
      access_type: "offline",
      include_granted_scopes: "true",
      prompt: "consent"
    }

    redirect_url = "#{@google_oauth_base}?#{URI.encode_query(params)}"
    json(conn, %{redirect_url: redirect_url})
  end

  def connect_google(conn, %{"code" => code}) do
    user = conn.assigns.current_user

    with {:ok, token_data} <- Google.exchange_code_for_tokens(code),
         {:ok, user_info} <- Google.fetch_user_info(token_data["access_token"]),
         {:ok, _} <- Google.save_auth(user.id, token_data, user_info) do
      json(conn, %{success: true, message: "Connected"})
    else
      {:error, reason} ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: inspect(reason)})
    end
  end

  def upload_to_google(conn, %{"filename" => filename, "file" => file}) do
    user = conn.assigns.current_user

    auth = Google.get_google_auth_by_id(user.id)

    case Google.upload_to_drive(auth, filename, "image/jpeg", file) do
      {:ok, response} -> json(conn, %{uploaded: true, data: response})
      {:error, reason} -> put_status(conn, 400) |> json(%{error: inspect(reason)})
    end
  end

  def is_google_connected(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Not authenticated"})
  end

  def is_google_connected(%{assigns: %{current_user: user}} = conn, _params) do
    connected = Google.get_google_auth_by_id(user.id) != nil
    json(conn, %{connected: connected})
  end
end
