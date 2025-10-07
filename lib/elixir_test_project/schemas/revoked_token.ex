defmodule ElixirTestProject.Schemas.RevokedToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @derive {Jason.Encoder, only: [:id, :jti, :user_id, :revoked_at, :inserted_at]}
  schema "revoked_tokens" do
    field :jti, :string
    field :user_id, Ecto.UUID
    field :revoked_at, :utc_datetime_usec

    timestamps()
  end

  def changeset(struct, params) do
    struct
    |> cast(params, [:jti, :user_id, :revoked_at])
    |> validate_required([:jti, :revoked_at])
    |> unique_constraint(:jti)
  end
end
