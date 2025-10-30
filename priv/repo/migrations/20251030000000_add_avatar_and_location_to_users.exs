defmodule ElixirTestProject.Repo.Migrations.AddAvatarAndLocationToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :avatar, :string
      add :coordinates, {:array, :float}, default: [], null: false
      add :location, :map
    end
  end
end
