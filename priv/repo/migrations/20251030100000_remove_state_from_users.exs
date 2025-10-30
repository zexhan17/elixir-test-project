defmodule ElixirTestProject.Repo.Migrations.RemoveStateFromUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      remove :state
    end
  end
end
