defmodule ElixirTestProject.Repo.Migrations.CreateMediaAssets do
  use Ecto.Migration

  def change do
    create table(:media_assets, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :object_key, :string, null: false
      add :filename, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :integer, null: false
      add :used, :boolean, null: false, default: false
      add :used_at, :utc_datetime
      add :storage_bucket, :string, null: false
      add :uploaded_by_id, references(:users, type: :binary_id, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:media_assets, [:object_key])
    create index(:media_assets, [:used])
  end
end
