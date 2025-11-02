defmodule ElixirTestProjectWeb.MediaController do
  use ElixirTestProjectWeb, :api_controller
  use OpenApiSpex.ControllerSpecs

  tags(["Media"])

  alias ElixirTestProject.Media
  alias ElixirTestProjectWeb.ApiSchemas

  operation(:upload,
    operation_id: "MediaUpload",
    summary: "Upload one or more images",
    description:
      "Accepts multipart file uploads, stores them in the configured MinIO/S3 bucket and records metadata for later reuse.",
    request_body: {
      "Multipart payload",
      "multipart/form-data",
      ApiSchemas.MediaUploadRequest
    },
    responses: %{
      201 => {"Upload successful", "application/json", ApiSchemas.MediaUploadResponse},
      400 =>
        {"Upload failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the payload is malformed or any unexpected error occurs."},
      415 =>
        {"Unsupported media type", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when any of the uploaded files is not an image."},
      422 =>
        {"Validation failed", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when no files are provided or an empty file is uploaded."},
      502 =>
        {"Storage failure", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when MinIO/S3 rejects the upload."}
    },
    security: [%{"bearerAuth" => []}]
  )

  @doc """
  Upload one or multiple images to the configured MinIO bucket.
  """
  def upload(%{assigns: %{current_user: user}} = conn, params) do
    IO.inspect(params, label: "[MediaController] Incoming params")

    files =
      case params do
        %{"files" => files} when is_list(files) ->
          Enum.filter(files, &match?(%Plug.Upload{}, &1))

        %{"files" => %Plug.Upload{} = file} ->
          [file]

        _ ->
          []
      end

    case Media.upload_images(files, uploaded_by: user) do
      {:ok, assets} ->
        conn
        |> put_status(:created)
        |> json(%{
          success: true,
          media:
            Enum.map(assets, fn asset ->
              %{
                id: asset.id,
                filename: asset.filename,
                content_type: asset.content_type,
                byte_size: asset.byte_size,
                used: asset.used,
                url: Media.backend_url(asset),
                inserted_at: asset.inserted_at
              }
            end)
        })

      {:error, :no_files_provided} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: "No files were provided"})

      {:error, :unsupported_media_type} ->
        conn
        |> put_status(:unsupported_media_type)
        |> json(%{success: false, error: "Only image uploads are supported"})

      {:error, :empty_file} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: "Uploaded files must not be empty"})

      {:error, {:upload_failed, reason}} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{success: false, error: "Failed to store file", reason: inspect(reason)})

      {:error, other} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: inspect(other)})
    end
  end

  def upload(conn, _params) do
    conn
    |> put_status(:unauthorized)
    |> json(%{success: false, error: "Unauthorized"})
  end

  operation(:signed_url,
    operation_id: "MediaSignedUrl",
    summary: "Retrieve a temporary signed URL for a media asset",
    description:
      "Returns a short-lived signed URL that allows clients to download the media asset directly from storage.",
    parameters: [
      id: [
        in: :path,
        description: "The ID of the media asset to sign",
        type: :string,
        required: true,
        example: "b04826cf-b841-49ff-9bce-e2cef80d63b2"
      ]
    ],
    responses: %{
      200 => {"Signed URL generated", "application/json", ApiSchemas.MediaSignedUrlResponse},
      400 =>
        {"Invalid request", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the provided ID is invalid."},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the media asset does not exist."},
      422 =>
        {"Unprocessable entity", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the media asset is missing the required object key."},
      502 =>
        {"Storage error", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the storage service fails to generate a signed URL."}
    },
    security: [%{"bearerAuth" => []}]
  )

  @doc """
  Returns a signed URL for downloading the media asset. The URL is valid for two minutes.
  """
  def signed_url(conn, %{"id" => id}) do
    case Media.presigned_media_url(id, expires_in: 120) do
      {:ok, %{url: url, expires_in: expires_in}} ->
        conn
        |> put_status(:ok)
        |> json(%{success: true, url: url, expires_in: expires_in})

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{success: false, error: "Media not found"})

      {:error, :invalid_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "Invalid media ID"})

      {:error, :invalid_expiration} ->
        conn
        |> put_status(:bad_request)
        |> json(%{success: false, error: "Invalid expiration interval"})

      {:error, :missing_object_key} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{success: false, error: "Media asset is missing an object key"})

      {:error, reason} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{
          success: false,
          error: "Failed to generate signed URL",
          reason: inspect(reason)
        })
    end
  end

  def signed_url(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{success: false, error: "Invalid request"})
  end

  @doc """
  Streams the media asset directly from MinIO/S3 to the client.
  """
  def stream_media(conn, %{"id" => id}) do
    case Media.get_media_stream(id) do
      {:ok, %{content_type: content_type, stream: stream}} ->
        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("cache-control", "public, max-age=31536000")
        |> send_resp(200, stream)

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Media not found"})

      {:error, reason} ->
        conn
        |> put_status(:bad_gateway)
        |> json(%{error: "Failed to stream media", reason: inspect(reason)})
    end
  end

  operation(:stream_media,
    operation_id: "MediaStream",
    summary: "Stream a media asset",
    description:
      "Streams the media asset directly from storage. This endpoint is publicly accessible.",
    parameters: [
      id: [
        in: :path,
        description: "The ID of the media asset to stream",
        type: :string,
        required: true,
        example: "b04826cf-b841-49ff-9bce-e2cef80d63b2"
      ]
    ],
    responses: %{
      200 =>
        {"Media file stream", "application/octet-stream",
         %OpenApiSpex.Schema{type: :string, format: :binary}},
      404 =>
        {"Not found", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the media asset does not exist."},
      502 =>
        {"Storage error", "application/json", ApiSchemas.ErrorResponse,
         description: "Returned when the storage service fails to stream the file."}
    }
  )
end
