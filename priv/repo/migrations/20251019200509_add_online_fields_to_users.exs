defmodule ElixirTestProject.Repo.Migrations.AddOnlineFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :online, :boolean, default: false, null: false
      add :last_online_at, :utc_datetime
    end
  end
end
