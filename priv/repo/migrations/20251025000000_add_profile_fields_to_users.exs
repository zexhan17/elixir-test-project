defmodule ElixirTestProject.Repo.Migrations.AddProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :city, :string
      add :state, :string
      add :country, :string
      add :address, :string
    end
  end
end
