defmodule ElixirTestProject.Google do
  @moduledoc """
  Handles Google OAuth logic, token storage, refresh, and API access
  (Drive & Photos upload/retrieve).
  """

  alias Ecto.Changeset
  alias ElixirTestProject.{Config, Repo}
  alias ElixirTestProject.Schemas.GoogleAuth

  require Logger

  @finch Req.Finch
  @token_url "https://oauth2.googleapis.com/token"
  @userinfo_url "https://www.googleapis.com/oauth2/v2/userinfo"
  @drive_upload_url "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart"
  @drive_files_url "https://www.googleapis.com/drive/v3/files"
  @photos_upload_url "https://photoslibrary.googleapis.com/v1/uploads"
  @photos_create_item_url "https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate"

  @doc """
  Exchanges an OAuth authorization code for Google access and refresh tokens.
  """
  def exchange_code_for_tokens(code) when is_binary(code) and byte_size(code) > 0 do
    oauth = Config.google_oauth_config()

    params = %{
      code: code,
      client_id: oauth.client_id,
      client_secret: oauth.client_secret,
      redirect_uri: oauth.callback_url,
      grant_type: "authorization_code"
    }

    case request(method: :post, url: @token_url, form: params) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        log_http_error("token exchange", status, body)
        {:error, {:http_error, status}}

      {:error, exception} ->
        Logger.error("Google token exchange network error: #{Exception.message(exception)}")
        {:error, {:network_error, exception}}
    end
  end

  def exchange_code_for_tokens(_), do: {:error, :invalid_code}

  @doc """
  Fetches Google user profile details using an access token.
  """
  def fetch_user_info(access_token) when is_binary(access_token) do
    headers = [{"authorization", "Bearer #{access_token}"}]

    case request(method: :get, url: @userinfo_url, headers: headers) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        log_http_error("user info", status, body)
        {:error, {:http_error, status}}

      {:error, exception} ->
        Logger.error("Google user info network error: #{Exception.message(exception)}")
        {:error, {:network_error, exception}}
    end
  end

  def fetch_user_info(_), do: {:error, :invalid_token}

  @doc """
  Persists or updates the stored Google OAuth credentials for the given user.
  """
  def save_auth(user_id, token_data, user_info)
      when is_binary(user_id) and is_map(token_data) and is_map(user_info) do
    expires_at =
      DateTime.utc_now()
      |> DateTime.add(Map.get(token_data, "expires_in", 3600), :second)

    attrs = %{
      user_id: user_id,
      google_user_id: user_info["id"],
      email: user_info["email"],
      name: user_info["name"],
      picture: user_info["picture"],
      access_token: token_data["access_token"],
      refresh_token: token_data["refresh_token"],
      expires_at: expires_at,
      scope: token_data["scope"],
      id_token: token_data["id_token"],
      token_type: token_data["token_type"]
    }

    changeset =
      case Repo.get_by(GoogleAuth, user_id: user_id) do
        %GoogleAuth{} = existing -> GoogleAuth.changeset(existing, attrs)
        nil -> GoogleAuth.changeset(%GoogleAuth{}, attrs)
      end

    changeset
    |> Repo.insert_or_update()
    |> log_save_auth_result(user_id, attrs[:google_user_id])
  end

  def save_auth(_, _, _), do: {:error, :invalid_attributes}

  defp log_save_auth_result({:ok, %GoogleAuth{} = auth} = result, user_id, google_user_id) do
    Logger.info("Stored Google OAuth credentials",
      user_id: user_id,
      google_user_id: google_user_id,
      auth_id: auth.id
    )

    result
  end

  defp log_save_auth_result(
         {:error, %Ecto.Changeset{} = changeset} = result,
         user_id,
         google_user_id
       ) do
    Logger.error("Failed to persist Google OAuth credentials",
      user_id: user_id,
      google_user_id: google_user_id,
      errors: inspect(changeset.errors)
    )

    result
  end

  defp log_save_auth_result(result, _user_id, _google_user_id), do: result

  @doc """
  Returns a valid Google access token, refreshing when the stored token has expired.
  """
  def get_valid_access_token(%GoogleAuth{} = auth) do
    if auth.expires_at && DateTime.compare(auth.expires_at, DateTime.utc_now()) == :gt do
      {:ok, auth.access_token}
    else
      refresh_access_token(auth)
    end
  end

  def get_valid_access_token(_), do: {:error, :missing_auth}

  @doc """
  Fetches the persisted Google auth record for a user id.
  """
  def get_google_auth_by_id(user_id) when is_binary(user_id) do
    Repo.get_by(GoogleAuth, user_id: user_id)
  end

  def get_google_auth_by_id(_), do: nil

  defp refresh_access_token(%GoogleAuth{refresh_token: nil, user_id: user_id}) do
    Logger.error("Cannot refresh Google token without a refresh_token", user_id: user_id)
    {:error, :missing_refresh_token}
  end

  defp refresh_access_token(%GoogleAuth{} = auth) do
    oauth = Config.google_oauth_config()

    params = %{
      refresh_token: auth.refresh_token,
      client_id: oauth.client_id,
      client_secret: oauth.client_secret,
      grant_type: "refresh_token"
    }

    case request(method: :post, url: @token_url, form: params) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        expires_at =
          DateTime.utc_now()
          |> DateTime.add(Map.get(body, "expires_in", 3600), :second)
          |> DateTime.truncate(:second)

        changeset =
          Changeset.change(auth, %{
            access_token: body["access_token"],
            expires_at: expires_at
          })

        case Repo.update(changeset) do
          {:ok, updated} ->
            {:ok, updated.access_token}

          {:error, changeset} ->
            Logger.error("Failed to persist refreshed Google token",
              user_id: auth.user_id,
              errors: inspect(changeset.errors)
            )

            {:error, :persist_failed}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        log_http_error("refresh token", status, body, user_id: auth.user_id)
        {:error, :refresh_failed}

      {:error, exception} ->
        Logger.error("Token refresh failed: #{Exception.message(exception)}",
          user_id: auth.user_id
        )

        {:error, :refresh_failed}
    end
  end

  @doc """
  Uploads a file to Google Drive for the authenticated user.
  """
  def upload_to_drive(nil, _filename, _mime_type, _file_binary), do: {:error, :missing_auth}

  def upload_to_drive(%GoogleAuth{} = auth, filename, mime_type, file_binary)
      when is_binary(filename) and is_binary(mime_type) and is_binary(file_binary) do
    with {:ok, access_token} <- get_valid_access_token(auth) do
      metadata = %{"name" => filename}
      boundary = "elixir-boundary-#{System.unique_integer([:positive])}"

      multipart_body =
        "--#{boundary}\r\n" <>
          "Content-Type: application/json; charset=UTF-8\r\n\r\n" <>
          "#{Jason.encode!(metadata)}\r\n" <>
          "--#{boundary}\r\n" <>
          "Content-Type: #{mime_type}\r\n\r\n" <>
          file_binary <>
          "\r\n" <>
          "--#{boundary}--"

      headers = [
        {"authorization", "Bearer #{access_token}"},
        {"content-type", "multipart/related; boundary=#{boundary}"}
      ]

      case request(method: :post, url: @drive_upload_url, headers: headers, body: multipart_body) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %Req.Response{status: status, body: body}} ->
          log_http_error("drive upload", status, body, user_id: auth.user_id)
          {:error, :upload_failed}

        {:error, exception} ->
          Logger.error("Drive upload failed: #{Exception.message(exception)}",
            user_id: auth.user_id,
            filename: filename
          )

          {:error, :upload_failed}
      end
    end
  end

  @doc """
  Lists Google Drive files accessible to the authenticated user.
  """
  def list_drive_files(nil), do: {:error, :missing_auth}

  def list_drive_files(%GoogleAuth{} = auth) do
    with {:ok, access_token} <- get_valid_access_token(auth) do
      headers = [{"authorization", "Bearer #{access_token}"}]

      case request(method: :get, url: @drive_files_url, headers: headers) do
        {:ok, %Req.Response{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %Req.Response{status: status, body: body}} ->
          log_http_error("drive list", status, body, user_id: auth.user_id)
          {:error, :list_failed}

        {:error, exception} ->
          Logger.error("Drive list failed: #{Exception.message(exception)}",
            user_id: auth.user_id
          )

          {:error, :list_failed}
      end
    end
  end

  @doc """
  Uploads media to Google Photos for the authenticated user.
  """
  def upload_to_photos(nil, _filename, _mime_type, _file_binary), do: {:error, :missing_auth}

  def upload_to_photos(%GoogleAuth{} = auth, filename, _mime_type, file_binary)
      when is_binary(filename) and is_binary(file_binary) do
    with {:ok, access_token} <- get_valid_access_token(auth),
         {:ok, upload_token} <- create_photos_upload_token(access_token, filename, file_binary),
         {:ok, response} <- finalize_photos_upload(access_token, upload_token) do
      {:ok, response}
    else
      {:error, reason} = error ->
        Logger.error("Google Photos upload failed",
          user_id: auth.user_id,
          filename: filename,
          reason: inspect(reason)
        )

        error
    end
  end

  defp create_photos_upload_token(access_token, filename, file_binary) do
    headers = [
      {"authorization", "Bearer #{access_token}"},
      {"content-type", "application/octet-stream"},
      {"x-goog-upload-file-name", filename},
      {"x-goog-upload-protocol", "raw"}
    ]

    case request(
           method: :post,
           url: @photos_upload_url,
           headers: headers,
           body: file_binary,
           decode_json: false
         ) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) and body != "" ->
        {:ok, body}

      {:ok, %Req.Response{status: status, body: body}} ->
        log_http_error("photos upload token", status, body)
        {:error, :upload_token_failed}

      {:error, exception} ->
        Logger.error("Photos upload token failed: #{Exception.message(exception)}")
        {:error, :upload_token_failed}
    end
  end

  defp finalize_photos_upload(access_token, upload_token) do
    body = %{
      newMediaItems: [
        %{
          description: "Uploaded via API",
          simpleMediaItem: %{uploadToken: upload_token}
        }
      ]
    }

    headers = [
      {"authorization", "Bearer #{access_token}"},
      {"content-type", "application/json"}
    ]

    case request(method: :post, url: @photos_create_item_url, headers: headers, json: body) do
      {:ok, %Req.Response{status: 200, body: response_body}} ->
        {:ok, response_body}

      {:ok, %Req.Response{status: status, body: response_body}} ->
        log_http_error("photos finalize", status, response_body)
        {:error, :photo_upload_failed}

      {:error, exception} ->
        Logger.error("Photos creation failed: #{Exception.message(exception)}")
        {:error, :photo_upload_failed}
    end
  end

  defp request(options) when is_list(options) do
    options
    |> Keyword.put_new(:finch, @finch)
    |> Keyword.put_new(:decode_json, [])
    |> Req.request()
  end

  defp log_http_error(action, status, body, metadata \\ []) do
    Logger.error(
      """
      Google #{action} returned #{status}: #{format_body(body)}
      """,
      metadata
    )
  end

  defp format_body(body) when is_binary(body), do: body
  defp format_body(body) when is_map(body), do: Jason.encode!(body)
  defp format_body(body), do: inspect(body)
end
