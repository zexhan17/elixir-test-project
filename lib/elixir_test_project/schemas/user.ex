defmodule ElixirTestProject.Schemas.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :phone, :string
    field :email, :string
    field :phone_code, :string
    field :password, :string, virtual: true
    field :password_hash, :string

    timestamps()
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :phone, :phone_code, :password, :email])
    |> validate_required([:name, :phone, :phone_code, :password])
    |> validate_length(:password, min: 10)
    |> unique_constraint(:phone)
    |> maybe_put_email_from_phone()
    |> put_password_hash()
  end

  defp maybe_put_email_from_phone(changeset) do
    case {get_field(changeset, :email), get_field(changeset, :phone)} do
      {nil, phone} when is_binary(phone) ->
        put_change(changeset, :email, phone <> "@phone.local")

      _ ->
        changeset
    end
  end

  defp put_password_hash(changeset) do
    case changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(password))

      _ ->
        changeset
    end
  end
end
