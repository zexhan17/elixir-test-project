defmodule ElixirTestProject.Gigs do
  @moduledoc """
  Context boundary for marketplace gig categories, types and gig records.
  Provides CRUD operations and flexible filtering for the API layer.
  """

  import Ecto.Query, warn: false

  alias ElixirTestProject.Repo
  alias ElixirTestProject.Schemas.{Gig, GigCategory, GigType}

  # ---------------------------------------------------------------------------
  # Categories
  # ---------------------------------------------------------------------------

  @doc """
  Returns all gig categories ordered alphabetically.
  """
  @spec list_categories() :: [GigCategory.t()]
  def list_categories do
    GigCategory
    |> order_by([c], asc: c.label)
    |> Repo.all()
  end

  @doc """
  Fetches a category by ID or returns nil.
  """
  @spec get_category(Ecto.UUID.t()) :: GigCategory.t() | nil
  def get_category(id), do: Repo.get(GigCategory, id)

  @doc """
  Fetches a single category by ID.
  """
  @spec get_category!(Ecto.UUID.t()) :: GigCategory.t()
  def get_category!(id), do: Repo.get!(GigCategory, id)

  @doc """
  Retrieves a category by key, returning nil when not found.
  """
  @spec get_category_by_key(String.t()) :: GigCategory.t() | nil
  def get_category_by_key(key) when is_binary(key) do
    Repo.get_by(GigCategory, key: key)
  end

  def get_category_by_key(_), do: nil

  @doc """
  Creates a category.
  """
  @spec create_category(map()) :: {:ok, GigCategory.t()} | {:error, Ecto.Changeset.t()}
  def create_category(attrs) when is_map(attrs) do
    %GigCategory{}
    |> GigCategory.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a category.
  """
  @spec update_category(GigCategory.t(), map()) ::
          {:ok, GigCategory.t()} | {:error, Ecto.Changeset.t()}
  def update_category(%GigCategory{} = category, attrs) when is_map(attrs) do
    category
    |> GigCategory.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a category.
  """
  @spec delete_category(GigCategory.t()) :: {:ok, GigCategory.t()} | {:error, Ecto.Changeset.t()}
  def delete_category(%GigCategory{} = category), do: Repo.delete(category)

  # ---------------------------------------------------------------------------
  # Types
  # ---------------------------------------------------------------------------

  @doc """
  Lists gig types. When `:category_id` filter is provided, only types for that
  category are returned.
  """
  @spec list_types(keyword()) :: [GigType.t()]
  def list_types(opts \\ []) do
    GigType
    |> maybe_filter_type_category(opts)
    |> order_by([t], asc: t.label)
    |> Repo.all()
  end

  defp maybe_filter_type_category(query, opts) do
    case Keyword.get(opts, :category_id) do
      nil -> query
      id -> where(query, [t], t.category_id == ^id)
    end
  end

  @doc """
  Fetches a gig type by ID.
  """
  @spec get_type!(Ecto.UUID.t()) :: GigType.t()
  def get_type!(id), do: Repo.get!(GigType, id)

  @doc """
  Fetches a gig type by ID or returns nil.
  """
  @spec get_type(Ecto.UUID.t()) :: GigType.t() | nil
  def get_type(id), do: Repo.get(GigType, id)

  @doc """
  Retrieves a gig type by unique key.
  """
  @spec get_type_by_key(String.t()) :: GigType.t() | nil
  def get_type_by_key(key) when is_binary(key), do: Repo.get_by(GigType, key: key)
  def get_type_by_key(_), do: nil

  @doc """
  Creates a gig type.
  Accepts either `:category_id` or `:category_key` to reference the parent category.
  """
  @spec create_type(map()) :: {:ok, GigType.t()} | {:error, term()}
  def create_type(attrs) when is_map(attrs) do
    with {:ok, normalized} <- normalize_type_attrs(attrs) do
      %GigType{}
      |> GigType.changeset(normalized)
      |> Repo.insert()
    end
  end

  @doc """
  Updates a gig type.
  """
  @spec update_type(GigType.t(), map()) :: {:ok, GigType.t()} | {:error, term()}
  def update_type(%GigType{} = type, attrs) when is_map(attrs) do
    with {:ok, normalized} <- normalize_type_attrs(attrs, allow_missing_category: true) do
      type
      |> GigType.changeset(normalized)
      |> Repo.update()
    end
  end

  @doc """
  Deletes a gig type.
  """
  @spec delete_type(GigType.t()) :: {:ok, GigType.t()} | {:error, Ecto.Changeset.t()}
  def delete_type(%GigType{} = type), do: Repo.delete(type)

  # ---------------------------------------------------------------------------
  # Gigs
  # ---------------------------------------------------------------------------

  @doc """
  Lists gigs applying optional filters.
  """
  @spec list_gigs(map()) :: [Gig.t()]
  def list_gigs(filters \\ %{}) when is_map(filters) do
    filters = normalize_gig_filters(filters)

    Gig
    |> preload([:category, :type])
    |> apply_gig_filters(filters)
    |> Repo.all()
  end

  @doc """
  Retrieves a gig by ID (raises if not found).
  """
  @spec get_gig!(Ecto.UUID.t()) :: Gig.t()
  def get_gig!(id) do
    Gig
    |> Repo.get!(id)
    |> Repo.preload([:category, :type])
  end

  @doc """
  Retrieves a gig by ID or returns nil.
  """
  @spec get_gig(Ecto.UUID.t()) :: Gig.t() | nil
  def get_gig(id), do: Repo.get(Gig, id)

  @doc """
  Creates a gig, normalising nested payloads from the HTTP layer.
  """
  @spec create_gig(map()) :: {:ok, Gig.t()} | {:error, term()}
  def create_gig(attrs) when is_map(attrs) do
    with {:ok, normalized} <- normalize_gig_attrs(attrs),
         :ok <- ensure_type_in_category(normalized.type_id, normalized.category_id) do
      %Gig{}
      |> Gig.changeset(normalized)
      |> Repo.insert()
      |> preload_gig()
    end
  end

  @doc """
  Updates an existing gig.
  """
  @spec update_gig(Gig.t(), map()) :: {:ok, Gig.t()} | {:error, term()}
  def update_gig(%Gig{} = gig, attrs) when is_map(attrs) do
    with {:ok, normalized} <- normalize_gig_attrs(attrs, allow_missing_refs: true),
         {:ok, normalized} <- default_missing_refs(gig, normalized),
         :ok <- ensure_type_in_category(normalized.type_id, normalized.category_id) do
      gig
      |> Gig.changeset(normalized)
      |> Repo.update()
      |> preload_gig()
    end
  end

  @doc """
  Deletes a gig.
  """
  @spec delete_gig(Gig.t()) :: {:ok, Gig.t()} | {:error, Ecto.Changeset.t()}
  def delete_gig(%Gig{} = gig), do: Repo.delete(gig)

  @doc """
  Marks a gig as active.
  """
  @spec activate_gig(Gig.t()) :: {:ok, Gig.t()} | {:error, term()}
  def activate_gig(%Gig{} = gig), do: set_active(gig, true)

  @doc """
  Marks a gig as inactive.
  """
  @spec deactivate_gig(Gig.t()) :: {:ok, Gig.t()} | {:error, term()}
  def deactivate_gig(%Gig{} = gig), do: set_active(gig, false)

  defp set_active(%Gig{} = gig, value) when is_boolean(value) do
    gig
    |> Gig.changeset(%{is_active: value})
    |> Repo.update()
    |> preload_gig()
  end

  defp preload_gig({:ok, %Gig{} = gig}), do: {:ok, Repo.preload(gig, [:category, :type])}
  defp preload_gig(other), do: other

  # ---------------------------------------------------------------------------
  # Normalization helpers
  # ---------------------------------------------------------------------------

  @type_attr_aliases %{
    category_id: [:category_id, "category_id", "categoryId"],
    category_key: [:category_key, "category_key", "categoryKey"],
    key: [:key, "key"],
    label: [:label, "label"],
    description: [:description, "description"]
  }

  defp normalize_type_attrs(attrs, opts \\ []) do
    allow_missing_category? = Keyword.get(opts, :allow_missing_category, false)

    attrs =
      attrs
      |> Map.new(fn {k, v} -> {normalize_type_key(k), v} end)
      |> Enum.reject(fn {k, _} -> is_nil(k) end)
      |> Map.new()

    cond do
      is_nil(attrs[:category_id]) and is_nil(attrs[:category_key]) and not allow_missing_category? ->
        {:error, :category_required}

      true ->
        with {:ok, attrs} <- maybe_put_category_id(attrs) do
          {:ok, Map.drop(attrs, [:category_key])}
        end
    end
  end

  defp normalize_type_key(key) do
    Enum.find_value(@type_attr_aliases, fn {attr, variants} ->
      if key in variants, do: attr, else: nil
    end)
  end

  defp maybe_put_category_id(attrs) do
    case attrs do
      %{category_id: id} when is_binary(id) ->
        {:ok, attrs}

      %{category_key: key} when is_binary(key) ->
        case get_category_by_key(key) do
          nil -> {:error, :category_not_found}
          %GigCategory{id: id} -> {:ok, Map.put(attrs, :category_id, id)}
        end

      _ ->
        {:ok, attrs}
    end
  end

  @gig_attr_aliases %{
    category_id: [:category_id, "category_id", "categoryId"],
    category_key: [:category_key, "category_key", "categoryKey"],
    type_id: [:type_id, "type_id", "typeId"],
    type_key: [:type_key, "type_key", "typeKey"],
    title: [:title, "title"],
    description: [:description, "description"],
    seller_name: [:seller_name, "seller_name", "sellerName"],
    seller_roles: [:seller_roles, "seller_roles", "sellerRoles", "seller_role", "sellerRole"],
    seller_location: [:seller_location, "seller_location", "sellerLocation"],
    availability_days: [:availability_days, "availability_days", "availabilityDays"],
    availability_timings: [:availability_timings, "availability_timings", "availabilityTimings"],
    order_min: [:order_min, "order_min", "orderMin"],
    order_max: [:order_max, "order_max", "orderMax"],
    reviews: [:reviews, "reviews"],
    review_count: [:review_count, "review_count", "reviewCount"],
    price: [:price, "price"],
    delivery_available: [:delivery_available, "delivery_available", "deliveryAvailable"],
    delivery_type: [:delivery_type, "delivery_type", "deliveryType"],
    delivery_areas: [:delivery_areas, "delivery_areas", "deliveryAreas"],
    delivery_radius_km: [:delivery_radius_km, "delivery_radius_km", "deliveryRadiusKm"],
    delivery_charges_type: [
      :delivery_charges_type,
      "delivery_charges_type",
      "deliveryChargesType"
    ],
    delivery_charges_amount: [
      :delivery_charges_amount,
      "delivery_charges_amount",
      "deliveryChargesAmount"
    ],
    delivery_charges_per_km_amount: [
      :delivery_charges_per_km_amount,
      "delivery_charges_per_km_amount",
      "deliveryChargesPerKmAmount"
    ],
    delivery_charges_free_above: [
      :delivery_charges_free_above,
      "delivery_charges_free_above",
      "deliveryChargesFreeAbove"
    ],
    subscription_available: [
      :subscription_available,
      "subscription_available",
      "subscriptionAvailable"
    ],
    subscription_type: [:subscription_type, "subscription_type", "subscriptionType"],
    subscription_description: [
      :subscription_description,
      "subscription_description",
      "subscriptionDescription"
    ],
    subscription_discount_percent: [
      :subscription_discount_percent,
      "subscription_discount_percent",
      "subscriptionDiscountPercent"
    ],
    subscription_price_per_month: [
      :subscription_price_per_month,
      "subscription_price_per_month",
      "subscriptionPricePerMonth"
    ],
    subscription_daily_quantity: [
      :subscription_daily_quantity,
      "subscription_daily_quantity",
      "subscriptionDailyQuantity"
    ],
    subscription_notes: [:subscription_notes, "subscription_notes", "subscriptionNotes"],
    extras: [:extras, "extras"],
    purity: [:purity, "purity"],
    is_active: [:is_active, "is_active", "isActive"],
    metadata: [:metadata, "metadata"]
  }

  defp normalize_gig_attrs(attrs, opts \\ []) when is_map(attrs) do
    allow_missing_refs? = Keyword.get(opts, :allow_missing_refs, false)

    attrs =
      attrs
      |> Map.new(fn
        {k, v} when is_atom(k) -> {k, v}
        {k, v} when is_binary(k) -> {normalize_gig_key(k), v}
        other -> other
      end)
      |> Enum.reject(fn {k, _} -> is_nil(k) end)
      |> Map.new()

    cond do
      not allow_missing_refs? and is_nil(attrs[:category_id]) and is_nil(attrs[:category_key]) ->
        {:error, :category_required}

      not allow_missing_refs? and is_nil(attrs[:type_id]) and is_nil(attrs[:type_key]) ->
        {:error, :type_required}

      true ->
        with {:ok, attrs} <- maybe_put_category_id(attrs),
             {:ok, attrs} <- maybe_put_type_id(attrs) do
          attrs
          |> Map.drop([:category_key, :type_key])
          |> merge_nested_payloads(attrs)
          |> then(&{:ok, &1})
        end
    end
  end

  defp normalize_gig_key(key) do
    Enum.find_value(@gig_attr_aliases, fn {attr, variants} ->
      if key in variants, do: attr, else: nil
    end)
  end

  defp maybe_put_type_id(attrs) do
    cond do
      Map.has_key?(attrs, :type_id) and is_binary(attrs.type_id) ->
        {:ok, attrs}

      Map.get(attrs, :type_key) ->
        case get_type_by_key(attrs.type_key) do
          nil -> {:error, :type_not_found}
          %GigType{id: id} -> {:ok, Map.put(attrs, :type_id, id)}
        end

      true ->
        {:ok, attrs}
    end
  end

  defp merge_nested_payloads(normalized, raw_attrs) do
    normalized
    |> Map.merge(extract_seller(raw_attrs))
    |> Map.merge(extract_availability(raw_attrs))
    |> Map.merge(extract_order_limits(raw_attrs))
    |> Map.merge(extract_delivery(raw_attrs))
    |> Map.merge(extract_subscription(raw_attrs))
    |> Map.merge(extract_extras_and_metadata(raw_attrs))
    |> maybe_put_default(:review_count, fetch_integer(raw_attrs, [:review_count]))
    |> maybe_put_default(:title, fetch_value(raw_attrs, [:title]))
    |> maybe_put_default(:description, fetch_value(raw_attrs, [:description]))
    |> maybe_put_default(:price, fetch_value(raw_attrs, [:price]))
    |> maybe_put_default(:reviews, fetch_value(raw_attrs, [:reviews]))
    |> maybe_put_default(:purity, fetch_value(raw_attrs, [:purity]))
    |> maybe_put_default(:is_active, fetch_boolean(raw_attrs, [:is_active]))
  end

  defp extract_seller(attrs) do
    {seller, _present?} = fetch_map(attrs, [:seller])

    %{}
    |> maybe_put_default(:seller_name, fetch_value(attrs, [:seller_name]))
    |> maybe_put_default(:seller_name, fetch_value(seller, [:name]))
    |> maybe_put_default(:seller_location, fetch_value(attrs, [:seller_location]))
    |> maybe_put_default(:seller_location, fetch_value(seller, [:location]))
    |> maybe_put_default(:seller_roles, fetch_list(attrs, [:seller_roles]))
    |> maybe_put_default(:seller_roles, fetch_list(seller, [:role]))
    |> maybe_put_default(:seller_roles, fetch_list(seller, [:roles]))
  end

  defp extract_availability(attrs) do
    {availability, _present?} = fetch_map(attrs, [:availability])

    %{}
    |> maybe_put_default(:availability_days, fetch_value(attrs, [:availability_days]))
    |> maybe_put_default(:availability_days, fetch_value(availability, [:days]))
    |> maybe_put_default(:availability_timings, fetch_value(attrs, [:availability_timings]))
    |> maybe_put_default(:availability_timings, fetch_value(availability, [:timings]))
  end

  defp extract_order_limits(attrs) do
    {limits, _present?} = fetch_map(attrs, [:order_limits])

    %{}
    |> maybe_put_default(:order_min, fetch_value(attrs, [:order_min]))
    |> maybe_put_default(:order_min, fetch_value(limits, [:min]))
    |> maybe_put_default(:order_max, fetch_value(attrs, [:order_max]))
    |> maybe_put_default(:order_max, fetch_value(limits, [:max]))
  end

  defp extract_delivery(attrs) do
    {delivery, _present?} = fetch_map(attrs, [:delivery])
    {charges, _charges_present?} = fetch_map(delivery, [:charges])

    %{}
    |> maybe_put_default(:delivery_available, fetch_boolean(attrs, [:delivery_available]))
    |> maybe_put_default(:delivery_available, fetch_boolean(delivery, [:available]))
    |> maybe_put_default(:delivery_type, fetch_value(attrs, [:delivery_type]))
    |> maybe_put_default(:delivery_type, fetch_value(delivery, [:type]))
    |> maybe_put_default(:delivery_areas, fetch_list(attrs, [:delivery_areas]))
    |> maybe_put_default(:delivery_areas, fetch_list(delivery, [:areasCovered]))
    |> maybe_put_default(:delivery_areas, fetch_list(delivery, [:areas_covered]))
    |> maybe_put_default(:delivery_radius_km, fetch_integer(attrs, [:delivery_radius_km]))
    |> maybe_put_default(:delivery_radius_km, fetch_integer(delivery, [:radiusKm]))
    |> maybe_put_default(:delivery_radius_km, fetch_integer(delivery, [:radius_km]))
    |> maybe_put_default(:delivery_charges_type, fetch_value(attrs, [:delivery_charges_type]))
    |> maybe_put_default(:delivery_charges_type, fetch_value(charges, [:type]))
    |> maybe_put_default(
      :delivery_charges_amount,
      fetch_integer(attrs, [:delivery_charges_amount])
    )
    |> maybe_put_default(:delivery_charges_amount, fetch_integer(charges, [:amount]))
    |> maybe_put_default(
      :delivery_charges_per_km_amount,
      fetch_integer(attrs, [:delivery_charges_per_km_amount])
    )
    |> maybe_put_default(
      :delivery_charges_per_km_amount,
      fetch_integer(charges, [:perKmAmount])
    )
    |> maybe_put_default(
      :delivery_charges_per_km_amount,
      fetch_integer(charges, [:per_km_amount])
    )
    |> maybe_put_default(
      :delivery_charges_free_above,
      fetch_integer(attrs, [:delivery_charges_free_above])
    )
    |> maybe_put_default(
      :delivery_charges_free_above,
      fetch_integer(charges, [:freeAbove])
    )
    |> maybe_put_default(
      :delivery_charges_free_above,
      fetch_integer(charges, [:free_above])
    )
  end

  defp extract_subscription(attrs) do
    {subscription, _present?} = fetch_map(attrs, [:subscription])

    %{}
    |> maybe_put_default(:subscription_available, fetch_boolean(attrs, [:subscription_available]))
    |> maybe_put_default(:subscription_available, fetch_boolean(subscription, [:available]))
    |> maybe_put_default(:subscription_type, fetch_value(attrs, [:subscription_type]))
    |> maybe_put_default(:subscription_type, fetch_value(subscription, [:type]))
    |> maybe_put_default(
      :subscription_description,
      fetch_value(attrs, [:subscription_description])
    )
    |> maybe_put_default(
      :subscription_description,
      fetch_value(subscription, [:description])
    )
    |> maybe_put_default(
      :subscription_discount_percent,
      fetch_integer(attrs, [:subscription_discount_percent])
    )
    |> maybe_put_default(
      :subscription_discount_percent,
      fetch_integer(subscription, [:discountPercent])
    )
    |> maybe_put_default(
      :subscription_discount_percent,
      fetch_integer(subscription, [:discount_percent])
    )
    |> maybe_put_default(
      :subscription_price_per_month,
      fetch_value(attrs, [:subscription_price_per_month])
    )
    |> maybe_put_default(
      :subscription_price_per_month,
      fetch_value(subscription, [:pricePerMonth])
    )
    |> maybe_put_default(
      :subscription_price_per_month,
      fetch_value(subscription, [:price_per_month])
    )
    |> maybe_put_default(
      :subscription_daily_quantity,
      fetch_value(attrs, [:subscription_daily_quantity])
    )
    |> maybe_put_default(
      :subscription_daily_quantity,
      fetch_value(subscription, [:dailyQuantity])
    )
    |> maybe_put_default(
      :subscription_daily_quantity,
      fetch_value(subscription, [:daily_quantity])
    )
    |> maybe_put_default(:subscription_notes, fetch_value(attrs, [:subscription_notes]))
    |> maybe_put_default(:subscription_notes, fetch_value(subscription, [:notes]))
  end

  defp extract_extras_and_metadata(attrs) do
    %{}
    |> maybe_put_default(:extras, fetch_list(attrs, [:extras]))
    |> maybe_put_default(:metadata, fetch_map(attrs, [:metadata]))
  end

  defp maybe_put_default(map, _field, {nil, _present? = false}), do: map
  defp maybe_put_default(map, _field, {nil, true}), do: map
  defp maybe_put_default(map, field, {value, true}), do: Map.put(map, field, value)
  defp maybe_put_default(map, _field, {value, false}) when value in [nil, %{}, []], do: map
  defp maybe_put_default(map, _field, {_value, false}), do: map

  defp fetch_value(map, keys) when is_map(map) do
    Enum.reduce_while(keys, {nil, false}, fn key, _acc ->
      case value_from(map, key) do
        {value, true} -> {:halt, {value, true}}
        {_value, false} -> {:cont, {nil, false}}
      end
    end)
  end

  defp fetch_map(map, keys) do
    case fetch_value(map, keys) do
      {%{} = value, true} -> {value, true}
      {value, true} when is_map(value) -> {value, true}
      _ -> {%{}, false}
    end
  end

  defp fetch_list(map, keys) do
    case fetch_value(map, keys) do
      {value, true} when is_list(value) -> {Enum.map(value, &to_string/1), true}
      {value, true} when is_binary(value) -> {[value], true}
      _ -> {[], false}
    end
  end

  defp fetch_integer(map, keys) do
    case fetch_value(map, keys) do
      {value, true} -> {parse_integer(value), true}
      _ -> {nil, false}
    end
  end

  defp fetch_boolean(map, keys) do
    case fetch_value(map, keys) do
      {value, true} -> {to_boolean(value), true}
      _ -> {nil, false}
    end
  end

  defp value_from(map, key) when is_map(map) do
    cond do
      Map.has_key?(map, key) ->
        {Map.get(map, key), true}

      is_atom(key) and Map.has_key?(map, Atom.to_string(key)) ->
        {Map.get(map, Atom.to_string(key)), true}

      is_binary(key) and Map.has_key?(map, key) ->
        {Map.get(map, key), true}

      is_binary(key) ->
        snake_key = Macro.underscore(key)

        if Map.has_key?(map, snake_key) do
          {Map.get(map, snake_key), true}
        else
          {nil, false}
        end

      true ->
        {nil, false}
    end
  end

  defp parse_integer(value) when is_integer(value), do: value

  defp parse_integer(value) when is_binary(value) do
    value
    |> String.trim()
    |> Integer.parse()
    |> case do
      {int, _} -> int
      :error -> nil
    end
  end

  defp parse_integer(_), do: nil

  defp to_boolean(value) when is_boolean(value), do: value

  defp to_boolean(value) when is_binary(value) do
    value
    |> String.downcase()
    |> case do
      "true" -> true
      "1" -> true
      "false" -> false
      "0" -> false
      _ -> nil
    end
  end

  defp to_boolean(value) when is_integer(value) do
    value != 0
  end

  defp to_boolean(_), do: nil

  defp default_missing_refs(%Gig{} = gig, attrs) do
    attrs =
      attrs
      |> maybe_put_if_missing(:category_id, gig.category_id)
      |> maybe_put_if_missing(:type_id, gig.type_id)

    case {attrs[:category_id], attrs[:type_id]} do
      {nil, _} -> {:error, :category_required}
      {_, nil} -> {:error, :type_required}
      _ -> {:ok, attrs}
    end
  end

  defp maybe_put_if_missing(map, field, value) do
    case Map.has_key?(map, field) do
      true -> map
      false -> Map.put(map, field, value)
    end
  end

  defp ensure_type_in_category(type_id, category_id) do
    case Repo.get(GigType, type_id) do
      nil ->
        {:error, :type_not_found}

      %GigType{category_id: ^category_id} ->
        :ok

      %GigType{} ->
        {:error, :type_not_in_category}
    end
  end

  # ---------------------------------------------------------------------------
  # Filters
  # ---------------------------------------------------------------------------

  @filter_aliases %{
    "category_id" => :category_id,
    :category_id => :category_id,
    "categoryId" => :category_id,
    "type_id" => :type_id,
    :type_id => :type_id,
    "typeId" => :type_id,
    "title" => :title,
    :title => :title,
    "seller_name" => :seller_name,
    "sellerName" => :seller_name,
    :seller_name => :seller_name,
    "seller_location" => :seller_location,
    "sellerLocation" => :seller_location,
    :seller_location => :seller_location,
    "delivery_available" => :delivery_available,
    "deliveryAvailable" => :delivery_available,
    :delivery_available => :delivery_available,
    "delivery_type" => :delivery_type,
    "deliveryType" => :delivery_type,
    :delivery_type => :delivery_type,
    "subscription_available" => :subscription_available,
    "subscriptionAvailable" => :subscription_available,
    :subscription_available => :subscription_available,
    "subscription_type" => :subscription_type,
    "subscriptionType" => :subscription_type,
    :subscription_type => :subscription_type,
    "price" => :price,
    :price => :price,
    "purity" => :purity,
    :purity => :purity,
    "is_active" => :is_active,
    "isActive" => :is_active,
    :is_active => :is_active,
    "review_count" => :review_count,
    "reviewCount" => :review_count,
    :review_count => :review_count
  }

  defp normalize_gig_filters(filters) do
    Enum.reduce(filters, %{}, fn
      {key, value}, acc ->
        case Map.get(@filter_aliases, key, Map.get(@filter_aliases, to_string(key))) do
          nil ->
            acc

          :delivery_available ->
            maybe_put_filter(acc, :delivery_available, to_boolean(value))

          :subscription_available ->
            maybe_put_filter(acc, :subscription_available, to_boolean(value))

          :is_active ->
            maybe_put_filter(acc, :is_active, to_boolean(value))

          :review_count ->
            maybe_put_filter(acc, :review_count, parse_integer(value))

          field ->
            maybe_put_filter(acc, field, value)
        end
    end)
  end

  defp maybe_put_filter(acc, _field, nil), do: acc
  defp maybe_put_filter(acc, field, value), do: Map.put(acc, field, value)

  @string_like_filters [:title, :seller_name, :seller_location, :price, :purity, :description]
  @exact_filters [:category_id, :type_id, :delivery_type, :subscription_type]
  @boolean_filters [:delivery_available, :subscription_available, :is_active]

  defp apply_gig_filters(query, filters) do
    Enum.reduce(filters, query, fn
      {field, value}, query when field in @string_like_filters and is_binary(value) ->
        where(query, [g], ilike(field(g, ^field), ^"%#{value}%"))

      {field, value}, query when field in @exact_filters and is_binary(value) ->
        where(query, [g], field(g, ^field) == ^value)

      {:review_count, value}, query when is_integer(value) ->
        where(query, [g], g.review_count >= ^value)

      {field, value}, query when field in @boolean_filters and is_boolean(value) ->
        where(query, [g], field(g, ^field) == ^value)

      {_field, _value}, query ->
        query
    end)
  end
end
