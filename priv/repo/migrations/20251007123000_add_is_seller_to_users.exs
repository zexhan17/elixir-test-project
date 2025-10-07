defmodule ElixirTestProject.Repo.Migrations.AddIsSellerToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :is_seller, :boolean, null: false, default: false
    end
  end
end
