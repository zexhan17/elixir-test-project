defmodule ElixirTestProject.Repo.Migrations.CreateRides do
  use Ecto.Migration

  def change do
    create table(:rides) do
      add :name, :string
      add :status, :string

      timestamps(type: :utc_datetime)
    end
  end
end
