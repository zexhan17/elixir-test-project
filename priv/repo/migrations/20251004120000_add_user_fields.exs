defmodule ElixirTestProject.Repo.Migrations.AddUserFields do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :name, :string, null: false
      add :phone, :string, null: false
      add :phone_code, :string, null: false
    end

    create unique_index(:users, [:phone])
  end
end
