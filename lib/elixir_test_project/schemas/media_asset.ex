defmodule ElixirTestProject.Schemas.MediaAsset do
  @moduledoc """
  Represents a stored media asset in a MinIO/S3 bucket.

  Media assets are created when uploads are received by the API and track
  whether the file is actively referenced by other records (via the `used`
  flag).
  """

  use Ecto.Schema
  import Ecto.Changeset
  alias ElixirTestProject.Schemas.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          object_key: String.t() | nil,
          filename: String.t() | nil,
          content_type: String.t() | nil,
          byte_size: non_neg_integer() | nil,
          used: boolean(),
          used_at: DateTime.t() | nil,
          storage_bucket: String.t() | nil,
          uploaded_by_id: Ecto.UUID.t() | nil,
          uploaded_by: User.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "media_assets" do
    field :object_key, :string
    field :filename, :string
    field :content_type, :string
    field :byte_size, :integer
    field :used, :boolean, default: false
    field :used_at, :utc_datetime
    field :storage_bucket, :string

    belongs_to :uploaded_by, ElixirTestProject.Schemas.User

    timestamps()
  end

  @doc """
  Changeset used when creating a media asset record.
  """
  def creation_changeset(media_asset, attrs) do
    media_asset
    |> cast(attrs, [
      :object_key,
      :filename,
      :content_type,
      :byte_size,
      :used,
      :used_at,
      :storage_bucket,
      :uploaded_by_id
    ])
    |> validate_required([:object_key, :filename, :content_type, :byte_size, :storage_bucket])
    |> validate_number(:byte_size, greater_than: 0)
    |> unique_constraint(:object_key)
  end

  @doc """
  Changeset used when toggling the `used` state of a media asset.
  """
  def usage_changeset(media_asset, attrs) do
    media_asset
    |> cast(attrs, [:used, :used_at])
    |> validate_required([:used])
  end
end
