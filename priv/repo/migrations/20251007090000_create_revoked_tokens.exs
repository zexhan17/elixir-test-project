defmodule ElixirTestProject.Repo.Migrations.CreateRevokedTokens do
  use Ecto.Migration

  def change do
    create table(:revoked_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :jti, :string, null: false
      add :user_id, :binary_id, null: true
      add :revoked_at, :utc_datetime_usec, null: false

      timestamps()
    end

    create unique_index(:revoked_tokens, [:jti])
    create index(:revoked_tokens, [:user_id])
  end
end
