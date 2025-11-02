defmodule ElixirTestProject.Schemas.Gig do
  @moduledoc """
  Marketplace gig offered by a seller, including availability, delivery and subscription details.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirTestProject.Schemas.{GigCategory, GigType}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          category_id: Ecto.UUID.t() | nil,
          type_id: Ecto.UUID.t() | nil,
          seller_name: String.t() | nil,
          seller_roles: list(String.t()) | nil,
          seller_location: String.t() | nil,
          availability_days: String.t() | nil,
          availability_timings: String.t() | nil,
          order_min: String.t() | nil,
          order_max: String.t() | nil,
          reviews: String.t() | nil,
          review_count: non_neg_integer(),
          price: String.t() | nil,
          delivery_available: boolean(),
          delivery_type: String.t() | nil,
          delivery_areas: list(String.t()) | nil,
          delivery_radius_km: integer() | nil,
          delivery_charges_type: String.t() | nil,
          delivery_charges_amount: integer() | nil,
          delivery_charges_per_km_amount: integer() | nil,
          delivery_charges_free_above: integer() | nil,
          subscription_available: boolean(),
          subscription_type: String.t() | nil,
          subscription_description: String.t() | nil,
          subscription_discount_percent: integer() | nil,
          subscription_price_per_month: String.t() | nil,
          subscription_daily_quantity: String.t() | nil,
          subscription_notes: String.t() | nil,
          extras: list(String.t()) | nil,
          purity: String.t() | nil,
          is_active: boolean(),
          metadata: map() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "gigs" do
    field :title, :string
    field :description, :string

    field :seller_name, :string
    field :seller_roles, {:array, :string}, default: []
    field :seller_location, :string

    field :availability_days, :string
    field :availability_timings, :string

    field :order_min, :string
    field :order_max, :string

    field :reviews, :string
    field :review_count, :integer, default: 0

    field :price, :string

    field :delivery_available, :boolean, default: false
    field :delivery_type, :string
    field :delivery_areas, {:array, :string}, default: []
    field :delivery_radius_km, :integer
    field :delivery_charges_type, :string
    field :delivery_charges_amount, :integer
    field :delivery_charges_per_km_amount, :integer
    field :delivery_charges_free_above, :integer

    field :subscription_available, :boolean, default: false
    field :subscription_type, :string
    field :subscription_description, :string
    field :subscription_discount_percent, :integer
    field :subscription_price_per_month, :string
    field :subscription_daily_quantity, :string
    field :subscription_notes, :string

    field :extras, {:array, :string}, default: []
    field :purity, :string

    field :is_active, :boolean, default: true
    field :metadata, :map, default: %{}

    belongs_to :category, GigCategory
    belongs_to :type, GigType

    timestamps()
  end

  @gig_fields [
    :title,
    :description,
    :category_id,
    :type_id,
    :seller_name,
    :seller_roles,
    :seller_location,
    :availability_days,
    :availability_timings,
    :order_min,
    :order_max,
    :reviews,
    :review_count,
    :price,
    :delivery_available,
    :delivery_type,
    :delivery_areas,
    :delivery_radius_km,
    :delivery_charges_type,
    :delivery_charges_amount,
    :delivery_charges_per_km_amount,
    :delivery_charges_free_above,
    :subscription_available,
    :subscription_type,
    :subscription_description,
    :subscription_discount_percent,
    :subscription_price_per_month,
    :subscription_daily_quantity,
    :subscription_notes,
    :extras,
    :purity,
    :is_active,
    :metadata
  ]

  @doc false
  def changeset(gig, attrs) do
    gig
    |> cast(attrs, @gig_fields)
    |> validate_required([:title, :category_id, :type_id, :seller_name])
    |> validate_length(:title, min: 3, max: 200)
    |> validate_number(:review_count, greater_than_or_equal_to: 0)
    |> maybe_validate_inclusion(:delivery_type, ["area-based", "distance-based"])
    |> maybe_validate_inclusion(:subscription_type, ["monthly", "weekly"])
    |> put_default_maps()
    |> assoc_constraint(:category)
    |> assoc_constraint(:type)
  end

  defp put_default_maps(changeset) do
    changeset
    |> put_default(:seller_roles, [])
    |> put_default(:delivery_areas, [])
    |> put_default(:extras, [])
    |> put_default(:metadata, %{})
  end

  defp put_default(changeset, field, default) do
    case {get_field(changeset, field), get_change(changeset, field)} do
      {nil, nil} -> put_change(changeset, field, default)
      _ -> changeset
    end
  end

  defp maybe_validate_inclusion(changeset, field, collection) do
    case get_field(changeset, field) do
      nil -> changeset
      _ -> validate_inclusion(changeset, field, collection)
    end
  end
end
