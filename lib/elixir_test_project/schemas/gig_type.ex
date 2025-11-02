defmodule ElixirTestProject.Schemas.GigType do
  @moduledoc """
  Represents a gig sub-type (e.g. Cow, Buffalo) within a gig category.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirTestProject.Schemas.{Gig, GigCategory}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          key: String.t() | nil,
          label: String.t() | nil,
          description: String.t() | nil,
          category_id: Ecto.UUID.t() | nil,
          category: GigCategory.t() | Ecto.Association.NotLoaded.t(),
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "gig_types" do
    field :key, :string
    field :label, :string
    field :description, :string

    belongs_to :category, GigCategory
    has_many :gigs, Gig, foreign_key: :type_id

    timestamps()
  end

  @doc false
  def changeset(type, attrs) do
    type
    |> cast(attrs, [:key, :label, :description, :category_id])
    |> validate_required([:key, :label, :category_id])
    |> validate_length(:key, min: 1, max: 60)
    |> validate_length(:label, min: 1, max: 120)
    |> assoc_constraint(:category)
    |> unique_constraint(:key)
    |> unique_constraint(:category_key,
      name: :gig_types_category_id_key_index,
      message: "has already been taken within this category"
    )
  end
end
