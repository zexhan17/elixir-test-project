defmodule ElixirTestProject.Google do
  @moduledoc """
  Handles Google OAuth logic, token storage, refresh, and API access
  (Drive & Photos upload/retrieve).
  """

  alias ElixirTestProject.{Repo, Schemas.GoogleAuth}
  require Logger

  @token_url "https://oauth2.googleapis.com/token"
  @userinfo_url "https://www.googleapis.com/oauth2/v2/userinfo"
  @drive_upload_url "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart"
  @drive_files_url "https://www.googleapis.com/drive/v3/files"
  @photos_upload_url "https://photoslibrary.googleapis.com/v1/uploads"
  @photos_create_item_url "https://photoslibrary.googleapis.com/v1/mediaItems:batchCreate"

  # === Exchange authorization code for tokens ===
  def exchange_code_for_tokens(code) do
    oauth = Application.get_env(:elixir_test_project, :google_oauth, [])

    body =
      URI.encode_query(%{
        code: code,
        client_id: oauth[:client_id],
        client_secret: oauth[:client_secret],
        redirect_uri: oauth[:callback_url],
        grant_type: "authorization_code"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case Finch.build(:post, @token_url, headers, body)
         |> Finch.request(ElixirTestProject.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %Finch.Response{status: s, body: b}} ->
        Logger.error("Google token exchange failed: #{inspect(b)}")
        {:error, {:http, s, b}}

      {:error, reason} ->
        Logger.error("Network error: #{inspect(reason)}")
        {:error, {:network, reason}}
    end
  end

  # === Fetch Google user info ===
  def fetch_user_info(access_token) do
    headers = [{"Authorization", "Bearer #{access_token}"}]

    case Finch.build(:get, @userinfo_url, headers)
         |> Finch.request(ElixirTestProject.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        {:ok, Jason.decode!(body)}

      {:ok, %Finch.Response{status: s, body: b}} ->
        Logger.error("User info error #{s}: #{b}")
        {:error, {:http, s, b}}

      {:error, reason} ->
        Logger.error("User info network error: #{inspect(reason)}")
        {:error, {:network, reason}}
    end
  end

  # === Save or update tokens ===
  def save_auth(user_id, token_data, user_info) do
    expires_at =
      DateTime.add(DateTime.utc_now(), token_data["expires_in"] || 3600, :second)

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

    existing = Repo.get_by(GoogleAuth, user_id: user_id)

    if existing do
      existing
      |> GoogleAuth.changeset(attrs)
      |> Repo.update()
    else
      %GoogleAuth{}
      |> GoogleAuth.changeset(attrs)
      |> Repo.insert()
    end
  end

  # === Access token management ===
  def get_valid_access_token(auth) do
    if DateTime.compare(auth.expires_at, DateTime.utc_now()) == :gt do
      {:ok, auth.access_token}
    else
      refresh_access_token(auth)
    end
  end

  def get_google_auth_by_id(user_id) do
    Repo.get_by(GoogleAuth, user_id: user_id)
  end

  defp refresh_access_token(auth) do
    oauth = Application.get_env(:elixir_test_project, :google_oauth, [])

    body =
      URI.encode_query(%{
        refresh_token: auth.refresh_token,
        client_id: oauth[:client_id],
        client_secret: oauth[:client_secret],
        grant_type: "refresh_token"
      })

    headers = [{"Content-Type", "application/x-www-form-urlencoded"}]

    case Finch.build(:post, @token_url, headers, body)
         |> Finch.request(ElixirTestProject.Finch) do
      {:ok, %Finch.Response{status: 200, body: body}} ->
        data = Jason.decode!(body)

        expires_at =
          DateTime.add(DateTime.utc_now(), data["expires_in"], :second)
          |> DateTime.truncate(:second)

        updated_auth =
          auth
          |> Ecto.Changeset.change(%{
            access_token: data["access_token"],
            expires_at: expires_at
          })
          |> Repo.update!()

        {:ok, updated_auth.access_token}

      error ->
        Logger.error("Token refresh failed: #{inspect(error)}")
        {:error, :refresh_failed}
    end
  end

  # === Upload file to Google Drive ===
  def upload_to_drive(auth, filename, mime_type, file_binary) do
    with {:ok, access_token} <- get_valid_access_token(auth) do
      metadata = %{"name" => filename}
      boundary = "boundary123"

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
        {"Authorization", "Bearer #{access_token}"},
        {"Content-Type", "multipart/related; boundary=#{boundary}"}
      ]

      case Finch.build(:post, @drive_upload_url, headers, multipart_body)
           |> Finch.request(ElixirTestProject.Finch) do
        {:ok, %Finch.Response{status: 200, body: body}} ->
          {:ok, Jason.decode!(body)}

        other ->
          Logger.error("Drive upload failed: #{inspect(other)}")
          {:error, :upload_failed}
      end
    end
  end

  # === List files from Google Drive ===
  def list_drive_files(auth) do
    with {:ok, access_token} <- get_valid_access_token(auth) do
      headers = [{"Authorization", "Bearer #{access_token}"}]

      case Finch.build(:get, @drive_files_url, headers)
           |> Finch.request(ElixirTestProject.Finch) do
        {:ok, %Finch.Response{status: 200, body: body}} ->
          {:ok, Jason.decode!(body)}

        other ->
          Logger.error("Drive list failed: #{inspect(other)}")
          {:error, :list_failed}
      end
    end
  end

  # === Upload image/video to Google Photos ===
  def upload_to_photos(auth, filename, _mime_type, file_binary) do
    with {:ok, access_token} <- get_valid_access_token(auth) do
      headers = [
        {"Authorization", "Bearer #{access_token}"},
        {"Content-Type", "application/octet-stream"},
        {"X-Goog-Upload-File-Name", filename},
        {"X-Goog-Upload-Protocol", "raw"}
      ]

      # Step 1: Upload raw bytes to get an upload token
      with {:ok, %Finch.Response{status: 200, body: upload_token}} <-
             Finch.build(:post, @photos_upload_url, headers, file_binary)
             |> Finch.request(ElixirTestProject.Finch) do
        # Step 2: Create media item from upload token
        create_body = %{
          newMediaItems: [
            %{
              description: "Uploaded via API",
              simpleMediaItem: %{uploadToken: upload_token}
            }
          ]
        }

        headers = [
          {"Authorization", "Bearer #{access_token}"},
          {"Content-Type", "application/json"}
        ]

        Finch.build(:post, @photos_create_item_url, headers, Jason.encode!(create_body))
        |> Finch.request(ElixirTestProject.Finch)
        |> case do
          {:ok, %Finch.Response{status: 200, body: body}} ->
            {:ok, Jason.decode!(body)}

          other ->
            Logger.error("Photos creation failed: #{inspect(other)}")
            {:error, :photo_upload_failed}
        end
      else
        other ->
          Logger.error("Photos upload token failed: #{inspect(other)}")
          {:error, :upload_token_failed}
      end
    end
  end
end
