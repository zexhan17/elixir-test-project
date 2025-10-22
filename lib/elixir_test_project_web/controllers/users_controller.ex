defmodule ElixirTestProjectWeb.UsersController do
  use ElixirTestProjectWeb, :controller
  action_fallback ElixirTestProjectWeb.FallbackController
  alias ElixirTestProject.{Config, Google, Users}

  @google_oauth_base "https://accounts.google.com/o/oauth2/v2/auth"
  @profile_response_fields ~w(name city state country address)a

  def get_google_redirect_link(conn, _params) do
    oauth_config = Config.google_oauth_config()
    client_id = oauth_config.client_id
    redirect_uri = oauth_config.callback_url

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

  def connect_google(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Not authenticated"})
  end

  def connect_google(conn, %{"code" => code}) do
    user = conn.assigns.current_user

    with {:ok, token_data} <- Google.exchange_code_for_tokens(code),
         {:ok, user_info} <- Google.fetch_user_info(token_data["access_token"]),
         {:ok, _auth} <- Google.save_auth(user.id, token_data, user_info) do
      json(conn, %{success: true, message: "Connected"})
    else
      {:error, reason} ->
        respond_google_error(conn, reason)
    end
  end

  def connect_google(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing \"code\" parameter"})
  end

  def upload_to_google(conn, %{"filename" => filename, "file" => %Plug.Upload{} = file}) do
    with %{assigns: %{current_user: user}} when not is_nil(user) <- conn,
         %{} = auth <- Google.get_google_auth_by_id(user.id),
         mime_type <- file.content_type || "application/octet-stream",
         {:ok, response} <- Google.upload_to_drive(auth, filename, mime_type, file) do
      json(conn, %{uploaded: true, data: response})
    else
      %{assigns: %{current_user: nil}} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Not authenticated"})

      nil ->
        conn
        |> put_status(:bad_request)
        |> json(%{error: "Google account not connected"})

      {:error, reason} ->
        respond_google_error(conn, reason)
    end
  end

  def upload_to_google(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Not authenticated"})
  end

  def upload_to_google(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "invalid_upload_payload"})
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

  def update_profile(%{assigns: %{current_user: nil}} = conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> json(%{error: "Not authenticated"})
  end

  def update_profile(%{assigns: %{current_user: user}} = conn, params) when is_map(params) do
    with {:ok, updated_user} <- Users.update_profile(user, params) do
      json(conn, %{
        success: true,
        message: "Profile updated successfully",
        profile: profile_payload(updated_user)
      })
    end
  end

  defp respond_google_error(conn, {:http_error, status}) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: "google_http_error", status: status})
  end

  defp respond_google_error(conn, {:network_error, _}) do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: "google_network_error"})
  end

  defp respond_google_error(conn, :missing_auth) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Google account not connected"})
  end

  defp respond_google_error(conn, error)
       when error in [
              :upload_failed,
              :upload_token_failed,
              :photo_upload_failed,
              :list_failed,
              :refresh_failed
            ] do
    conn
    |> put_status(:bad_gateway)
    |> json(%{error: to_string(error)})
  end

  defp respond_google_error(conn, %Ecto.Changeset{} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "validation_failed", details: translate_errors(changeset)})
  end

  defp respond_google_error(conn, error) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: to_string(error)})
  end

  defp profile_payload(user) do
    user
    |> Map.take(@profile_response_fields)
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
