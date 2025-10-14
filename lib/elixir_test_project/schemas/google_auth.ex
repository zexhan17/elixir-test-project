defmodule ElixirTestProject.Schemas.GoogleAuth do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "google_auths" do
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

    belongs_to :user, ElixirTestProject.Schemas.User

    timestamps()
  end

  def changeset(google_auth, attrs) do
    google_auth
    |> cast(attrs, [
      :google_user_id,
      :email,
      :name,
      :picture,
      :access_token,
      :refresh_token,
      :expires_at,
      :scope,
      :id_token,
      :token_type,
      :user_id
    ])
    |> validate_required([:user_id, :access_token])
  end
end
