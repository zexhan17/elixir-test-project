defmodule ElixirTestProject.Media do
  @moduledoc """
  Media context responsible for uploading assets to MinIO/S3 and streaming them back.
  Handles image upload validation, storage, and retrieval.
  """

  import Ecto.Query, warn: false

  alias ExAws.S3
  alias ElixirTestProject.Config
  alias ElixirTestProject.Repo
  alias ElixirTestProject.Schemas.MediaAsset

  require Logger

  @doc """
  Uploads a list of `Plug.Upload` structs to the configured bucket.

  Returns `{:ok, [%MediaAsset{}]}` on success or `{:error, reason}` when any
  of the uploads fail. When an error occurs, already uploaded objects will be
  left in place but logged for manual cleanup.
  """
  @spec upload_images([Plug.Upload.t()], keyword()) ::
          {:ok, [MediaAsset.t()]} | {:error, term()}
  def upload_images(uploads, opts \\ [])

  def upload_images(uploads, opts) when is_list(uploads) do
    if Enum.empty?(uploads) do
      {:error, :no_files_provided}
    else
      bucket = Config.media_bucket()
      uploaded_by = Keyword.get(opts, :uploaded_by)

      uploads
      |> Enum.reduce_while({:ok, []}, fn upload, {:ok, acc} ->
        with {:ok, normalized} <- normalize_upload(upload),
             {:ok, object_key} <- put_object(bucket, normalized),
             {:ok, asset} <- persist_asset(bucket, object_key, normalized, uploaded_by) do
          {:cont, {:ok, [asset | acc]}}
        else
          {:error, reason} = error ->
            Logger.error("Failed to upload media asset", reason: inspect(reason))
            {:halt, error}
        end
      end)
      |> case do
        {:ok, assets} -> {:ok, Enum.reverse(assets)}
        other -> other
      end
    end
  rescue
    error ->
      Logger.error("Unexpected error during media upload", error: inspect(error))
      {:error, :upload_failed}
  end

  def upload_images(_other, _opts), do: {:error, :invalid_payload}

  @doc """
  Retrieves a single media asset by ID, returning `nil` when not found.
  """
  @spec get_media_asset(Ecto.UUID.t()) :: MediaAsset.t() | nil
  def get_media_asset(id) when is_binary(id), do: Repo.get(MediaAsset, id)
  def get_media_asset(_), do: nil

  @doc """
  Get a media stream directly from S3/MinIO with content type.
  """
  @spec get_media_stream(Ecto.UUID.t()) ::
          {:ok, %{content_type: String.t(), stream: String.t()}} | {:error, term()}
  def get_media_stream(id) when is_binary(id) do
    case get_media_asset(id) do
      nil ->
        {:error, :not_found}

      asset ->
        bucket = asset.storage_bucket || ElixirTestProject.Config.media_bucket()
        object_key = asset.object_key || asset.key

        with {:ok, resp} <- S3.get_object(bucket, object_key) |> ExAws.request(),
             stream = Map.get(resp, :body),
             headers = normalize_headers(resp.headers),
             content_type <- Map.get(headers, "content-type", asset.content_type) do
          {:ok, %{content_type: content_type, stream: stream}}
        else
          {:error, reason} -> {:error, reason}
        end
    end
  end

  @doc """
  Generates a presigned URL that allows downloading the media asset for a limited time.
  """
  @spec presigned_media_url(Ecto.UUID.t(), keyword()) ::
          {:ok, %{url: String.t(), expires_in: pos_integer()}} | {:error, term()}
  def presigned_media_url(id, opts \\ [])

  def presigned_media_url(id, opts) when is_binary(id) do
    expires_in = Keyword.get(opts, :expires_in, 120)

    if is_integer(expires_in) and expires_in > 0 do
      case get_media_asset(id) do
        nil ->
          {:error, :not_found}

        asset ->
          bucket = asset.storage_bucket || Config.media_bucket()
          object_key = asset.object_key || Map.get(asset, :key)

          if is_binary(object_key) and object_key != "" do
            config = ExAws.Config.new(:s3)

            case S3.presigned_url(config, :get, bucket, object_key, expires_in: expires_in) do
              {:ok, url} ->
                {:ok, %{url: url, expires_in: expires_in}}

              {:error, reason} ->
                {:error, reason}
            end
          else
            {:error, :missing_object_key}
          end
      end
    else
      {:error, :invalid_expiration}
    end
  end

  def presigned_media_url(_id, _opts), do: {:error, :invalid_id}

  @doc """
  Extracts a media asset ID from a backend streaming URL.

  Returns a list containing the ID if found, or an empty list if the URL
  is not a valid media asset URL.
  """
  @spec extract_id_from_url(String.t()) :: [String.t()]
  def extract_id_from_url(url) when is_binary(url) do
    uri = URI.parse(url)

    case uri.path do
      path when is_binary(path) ->
        path
        |> String.split("/")
        |> Enum.reject(&(&1 == ""))
        |> case do
          ["api", "media", "stream", id] -> [id]
          ["api", "media", id] -> [id]
          _ -> []
        end

      _ ->
        []
    end
  end

  def extract_id_from_url(_), do: []

  @doc """
  Deletes all unused media assets from S3 and the database.
  """
  @spec cleanup_unused_media() :: %{deleted: non_neg_integer(), failures: [MediaAsset.t()]}
  def cleanup_unused_media do
    bucket = Config.media_bucket()
    unused_assets = Repo.all(from m in MediaAsset, where: m.used == false)

    unused_assets
    |> Enum.reduce(%{deleted: 0, failures: []}, fn asset, acc ->
      bucket_name = asset.storage_bucket || bucket

      case delete_remote_asset(bucket_name, asset.object_key) do
        {:ok, _} ->
          {:ok, _} = Repo.delete(asset)
          %{acc | deleted: acc.deleted + 1}

        {:error, reason} ->
          Logger.error("Failed to delete unused media asset from storage",
            object_key: asset.object_key,
            reason: inspect(reason)
          )

          %{acc | failures: [asset | acc.failures]}
      end
    end)
    |> Map.update!(:failures, &Enum.reverse/1)
  end

  defp normalize_upload(
         %Plug.Upload{filename: filename, content_type: content_type, path: path} = upload
       ) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} when size > 0 ->
        detected_type = detect_content_type(upload, filename, content_type)

        if image_content_type?(detected_type) do
          case File.read(path) do
            {:ok, binary} ->
              {:ok,
               %{
                 filename: filename,
                 content_type: detected_type,
                 binary: binary,
                 byte_size: size
               }}

            {:error, reason} ->
              {:error, {:file_read_failed, reason}}
          end
        else
          {:error, :unsupported_media_type}
        end

      {:ok, _} ->
        {:error, :empty_file}

      {:error, reason} ->
        {:error, {:stat_failed, reason}}
    end
  end

  defp normalize_upload(_), do: {:error, :invalid_upload}

  defp detect_content_type(_upload, filename, provided) when is_binary(provided) do
    if String.starts_with?(provided, "image/") do
      provided
    else
      detect_from_filename(filename)
    end
  end

  defp detect_content_type(_upload, filename, _provided), do: detect_from_filename(filename)

  defp detect_from_filename(filename) do
    case MIME.from_path(filename) do
      value when is_binary(value) -> value
      _ -> "application/octet-stream"
    end
  end

  defp image_content_type?(content_type) do
    is_binary(content_type) and String.starts_with?(content_type, "image/")
  end

  defp put_object(bucket, %{binary: binary, content_type: content_type} = normalized) do
    object_key = build_object_key(normalized)

    bucket
    |> S3.put_object(object_key, binary, content_type: content_type)
    |> ExAws.request()
    |> case do
      {:ok, _} -> {:ok, object_key}
      {:error, reason} -> {:error, {:upload_failed, reason}}
    end
  end

  defp persist_asset(bucket, object_key, normalized, uploaded_by) do
    attrs = %{
      object_key: object_key,
      filename: normalized.filename,
      content_type: normalized.content_type,
      byte_size: normalized.byte_size,
      storage_bucket: bucket,
      used: false,
      used_at: nil
    }

    attrs =
      case uploaded_by do
        %_{} = user -> Map.put(attrs, :uploaded_by_id, user.id)
        _ -> attrs
      end

    %MediaAsset{}
    |> MediaAsset.creation_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns the public URL for streaming a media asset.
  """
  @spec backend_url(MediaAsset.t()) :: String.t()
  def backend_url(%MediaAsset{id: id}) when is_binary(id) do
    base = ElixirTestProjectWeb.Endpoint.url()
    Path.join([base, "api", "media", "stream", id])
  end

  defp normalize_headers(headers) when is_list(headers) do
    Enum.reduce(headers, %{}, fn {key, value}, acc ->
      put_normalized_header(acc, key, value)
    end)
  end

  defp normalize_headers(headers) when is_map(headers) do
    Enum.reduce(headers, %{}, fn {key, value}, acc ->
      put_normalized_header(acc, key, value)
    end)
  end

  defp normalize_headers(_), do: %{}

  defp put_normalized_header(acc, key, value) do
    case normalize_header_key(key) do
      nil -> acc
      normalized -> Map.put(acc, normalized, value)
    end
  end

  defp normalize_header_key(key) when is_binary(key), do: String.downcase(key)

  defp normalize_header_key(key) when is_atom(key),
    do: key |> Atom.to_string() |> String.downcase()

  defp normalize_header_key(_), do: nil

  defp build_object_key(%{filename: filename}) do
    extension =
      filename
      |> Path.extname()
      |> String.downcase()

    uuid = Ecto.UUID.generate()
    "#{uuid}#{extension}"
  end

  defp delete_remote_asset(bucket, object_key) do
    bucket
    |> S3.delete_object(object_key)
    |> ExAws.request()
  end
end
