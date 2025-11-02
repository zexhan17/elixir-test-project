defmodule ElixirTestProject.Repo.Migrations.CreateGigTables do
  use Ecto.Migration

  def change do
    create table(:gig_categories, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :label, :string, null: false
      add :description, :text

      timestamps()
    end

    create unique_index(:gig_categories, [:key])

    create table(:gig_types, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :category_id,
          references(:gig_categories, type: :binary_id, on_delete: :delete_all),
          null: false

      add :key, :string, null: false
      add :label, :string, null: false
      add :description, :text

      timestamps()
    end

    create index(:gig_types, [:category_id])
    create unique_index(:gig_types, [:key])
    create unique_index(:gig_types, [:category_id, :key])

    create table(:gigs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :category_id,
          references(:gig_categories, type: :binary_id, on_delete: :restrict),
          null: false

      add :type_id,
          references(:gig_types, type: :binary_id, on_delete: :restrict),
          null: false

      add :title, :string, null: false
      add :description, :text

      add :seller_name, :string, null: false
      add :seller_roles, {:array, :string}
      add :seller_location, :string

      add :availability_days, :string
      add :availability_timings, :string

      add :order_min, :string
      add :order_max, :string

      add :reviews, :string
      add :review_count, :integer, default: 0, null: false

      add :price, :string

      add :delivery_available, :boolean, default: false, null: false
      add :delivery_type, :string
      add :delivery_areas, {:array, :string}
      add :delivery_radius_km, :integer
      add :delivery_charges_type, :string
      add :delivery_charges_amount, :integer
      add :delivery_charges_per_km_amount, :integer
      add :delivery_charges_free_above, :integer

      add :subscription_available, :boolean, default: false, null: false
      add :subscription_type, :string
      add :subscription_description, :text
      add :subscription_discount_percent, :integer
      add :subscription_price_per_month, :string
      add :subscription_daily_quantity, :string
      add :subscription_notes, :text

      add :extras, {:array, :string}
      add :purity, :string

      add :is_active, :boolean, default: true, null: false
      add :metadata, :map, default: %{}

      timestamps()
    end

    create index(:gigs, [:category_id])
    create index(:gigs, [:type_id])
    create index(:gigs, [:is_active])
    create index(:gigs, [:seller_name])
    create index(:gigs, [:seller_location])
  end
end
