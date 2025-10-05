defmodule ElixirTestProject.Repo.Migrations.CreateCars do
  use Ecto.Migration

  def change do
    create table(:cars) do
      add :name, :string
      add :year, :string

      timestamps(type: :utc_datetime)
    end
  end
end
