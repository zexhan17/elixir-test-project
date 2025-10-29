defmodule ElixirTestProject.Schemas.GoogleAuth do
  @moduledoc """
  Stores Google OAuth tokens and metadata for a user.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "google_auths" do
    belongs_to :user, ElixirTestProject.Schemas.User

    field :google_user_id, :string
    field :email, :string
    field :name, :string
    field :picture, :string

    field :access_token, :string
    field :refresh_token, :string
    field :expires_at, :utc_datetime
    field :scope, :string
    field :id_token, :string
    field :token_type, :string

    timestamps()
  end

  @doc """
  Changeset for creating/updating Google auth records.
  """
  def changeset(google_auth, attrs) do
    google_auth
    |> cast(attrs, [
      :user_id,
      :google_user_id,
      :email,
      :name,
      :picture,
      :access_token,
      :refresh_token,
      :expires_at,
      :scope,
      :id_token,
      :token_type
    ])
    |> validate_required([:user_id, :google_user_id, :access_token, :expires_at])
    |> unique_constraint(:google_user_id)
    |> foreign_key_constraint(:user_id)
  end
end
