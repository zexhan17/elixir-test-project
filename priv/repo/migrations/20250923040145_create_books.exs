defmodule ElixirTestProject.Repo.Migrations.CreateBooks do
  use Ecto.Migration

  def change do
    create table(:books) do
      add :title, :string, null: false
      add :author, :string, null: false
      add :publication_year, :integer

      timestamps()
    end
  end
end
