defmodule ElixirTestProject.Repo.Migrations.CreateGoogleAuths do
  use Ecto.Migration

  def change do
    create table(:google_auths, primary_key: false) do
      add :id, :binary_id, primary_key: true

      # 👇 This is the critical fix
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :google_user_id, :string
      add :email, :string
      add :name, :string
      add :picture, :string

      add :access_token, :text
      add :refresh_token, :text
      add :expires_at, :utc_datetime
      add :scope, :string
      add :id_token, :text
      add :token_type, :string

      timestamps()
    end

    create index(:google_auths, [:user_id])
    create unique_index(:google_auths, [:google_user_id])
  end
end
