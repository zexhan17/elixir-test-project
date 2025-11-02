defmodule ElixirTestProject.Schemas.GigCategory do
  @moduledoc """
  Represents a high-level gig category (e.g. Milk, Water) exposed to the frontend.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirTestProject.Schemas.GigType

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          key: String.t() | nil,
          label: String.t() | nil,
          description: String.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

  schema "gig_categories" do
    field :key, :string
    field :label, :string
    field :description, :string

    has_many :types, GigType, foreign_key: :category_id

    timestamps()
  end

  @doc false
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:key, :label, :description])
    |> validate_required([:key, :label])
    |> validate_length(:key, min: 1, max: 60)
    |> validate_length(:label, min: 1, max: 120)
    |> unique_constraint(:key)
  end
end
