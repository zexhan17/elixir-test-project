defmodule ElixirTestProjectWeb.ApiSchemas do
  @moduledoc """
  Centralised OpenAPI schema definitions reused across controller operations.
  """

  alias OpenApiSpex.{Operation, Schema}
  require OpenApiSpex

  defmodule User do
    @moduledoc false

    OpenApiSpex.schema(%Schema{
      title: "User",
      type: :object,
      required: [:id, :name, :phone, :phone_code, :is_seller, :online, :inserted_at],
      properties: %{
        id: %Schema{type: :string, format: :uuid, example: "8de2c621-b7bb-4aeb-8c16-5d9e8d363c2d"},
        name: %Schema{type: :string, example: "Ada Lovelace"},
        avatar: %Schema{type: :string, nullable: true, example: "https://example.com/avatar.jpg"},
        coordinates: %Schema{
          type: :array,
          items: %Schema{type: :number},
          example: [51.5074, -0.1278]
        },
        location: %Schema{
          type: :object,
          additionalProperties: true,
          nullable: true,
          example: %{"type" => "Point", "coordinates" => [51.5074, -0.1278]}
        },
        city: %Schema{type: :string, nullable: true, example: "London"},
        state: %Schema{type: :string, nullable: true, example: "Greater London"},
        country: %Schema{type: :string, nullable: true, example: "UK"},
        address: %Schema{type: :string, nullable: true, example: "12 Analytical Engine Way"},
        phone: %Schema{type: :string, example: "441234567890"},
        phone_code: %Schema{type: :string, example: "+44"},
        is_seller: %Schema{
          type: :boolean,
          description: "Whether the user is registered as a seller.",
          example: false
        },
        online: %Schema{type: :boolean, example: true},
        last_online_at: %Schema{
          type: :string,
          format: :"date-time",
          nullable: true,
          example: "2024-02-20T18:41:13Z"
        },
        inserted_at: %Schema{type: :string, format: :"date-time", example: "2024-02-20T17:41:13Z"},
        updated_at: %Schema{type: :string, format: :"date-time", example: "2024-02-20T17:56:13Z"}
      }
    })
  end

  defmodule RegisterRequest do
    @moduledoc false

    OpenApiSpex.schema(%Schema{
      title: "RegisterRequest",
      type: :object,
      required: [:name, :phone, :phoneCode, :password],
      properties: %{
        name: %Schema{type: :string, maxLength: 120, example: "Ada Lovelace"},
        phone: %Schema{type: :string, example: "441234567890"},
        phoneCode: %Schema{type: :string, example: "+44"},
        password: %Schema{type: :string, minLength: 10, example: "3xtremelySafe!"}
      },
      example: %{
        "name" => "Ada Lovelace",
        "phone" => "441234567890",
        "phoneCode" => "+44",
        "password" => "3xtremelySafe!"
      }
    })
  end

  defmodule RegisterResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "RegisterResponse",
      type: :object,
      required: [:message, :user],
      properties: %{
        message: %Schema{type: :string, example: "User registered successfully"},
        user: User.schema()
      }
    })
  end

  defmodule LoginRequest do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "LoginRequest",
      type: :object,
      required: [:phoneCode, :phone, :password],
      properties: %{
        phoneCode: %Schema{type: :string, example: "+44"},
        phone: %Schema{type: :string, example: "441234567890"},
        password: %Schema{type: :string, example: "3xtremelySafe!"}
      },
      example: %{
        "phoneCode" => "+44",
        "phone" => "441234567890",
        "password" => "3xtremelySafe!"
      }
    })
  end

  defmodule LoginResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "LoginResponse",
      type: :object,
      required: [:message, :token, :user],
      properties: %{
        message: %Schema{type: :string, example: "Login successful"},
        token: %Schema{
          type: :string,
          description: "JWT access token",
          example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
        },
        user: User.schema()
      }
    })
  end

  defmodule RefreshTokenResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "RefreshTokenResponse",
      type: :object,
      required: [:message, :token, :user],
      properties: %{
        message: %Schema{type: :string, example: "Token refreshed"},
        token: %Schema{type: :string, example: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"},
        user: User.schema()
      }
    })
  end

  defmodule VerifyTokenResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "VerifyTokenResponse",
      type: :object,
      required: [:valid],
      properties: %{
        valid: %Schema{type: :boolean, example: true},
        claims: %Schema{
          type: :object,
          additionalProperties: true,
          nullable: true,
          description: "Decoded JWT claims returned when the token is valid.",
          example: %{
            "sub" => "8de2c621-b7bb-4aeb-8c16-5d9e8d363c2d",
            "phone" => "441234567890",
            "phone_code" => "+44"
          }
        },
        error: %Schema{type: :string, nullable: true, example: "token_revoked"}
      }
    })
  end

  defmodule LogoutResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "LogoutResponse",
      type: :object,
      required: [:logout],
      properties: %{
        logout: %Schema{type: :boolean, example: true},
        error: %Schema{type: :string, nullable: true, example: "invalid_token"}
      }
    })
  end

  defmodule ErrorResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "ErrorResponse",
      type: :object,
      required: [:error],
      properties: %{
        error: %Schema{type: :string, example: "invalid_credentials"},
        message: %Schema{type: :string, nullable: true, example: "User registered successfully"},
        details: %Schema{
          type: :object,
          nullable: true,
          additionalProperties: true,
          example: %{"phone" => ["has already been taken"]}
        },
        errors: %Schema{
          type: :object,
          nullable: true,
          additionalProperties: true,
          example: %{"phone" => ["has already been taken"]}
        }
      }
    })
  end

  defmodule UpdateProfileRequest do
    @moduledoc false
    properties = %{
      name: %Schema{type: :string, maxLength: 120},
      city: %Schema{type: :string, maxLength: 120},
      country: %Schema{type: :string, maxLength: 120},
      avatar: %Schema{type: :string, maxLength: 1000},
      coordinates: %Schema{
        type: :array,
        items: %Schema{type: :number},
        minItems: 2,
        maxItems: 2,
        description: "Array of [latitude, longitude]"
      },
      location: %Schema{
        type: :object,
        additionalProperties: true,
        description: "GeoJSON object or other location metadata"
      }
    }

    OpenApiSpex.schema(%Schema{
      title: "UpdateProfileRequest",
      type: :object,
      properties: properties,
      example: %{
        "name" => "Ada Lovelace",
        "city" => "London",
        "country" => "UK",
        "address" => "12 Analytical Engine Way"
      }
    })
  end

  defmodule UserProfile do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "UserProfile",
      type: :object,
      properties: %{
        name: %Schema{type: :string, nullable: true, example: "Ada Lovelace"},
        city: %Schema{type: :string, nullable: true, example: "London"},
        state: %Schema{type: :string, nullable: true, example: "Greater London"},
        country: %Schema{type: :string, nullable: true, example: "UK"},
        address: %Schema{type: :string, nullable: true, example: "12 Analytical Engine Way"}
      }
    })
  end

  defmodule UpdateProfileResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "UpdateProfileResponse",
      type: :object,
      required: [:success, :message, :profile],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        message: %Schema{type: :string, example: "Profile updated successfully"},
        profile: UserProfile.schema()
      }
    })
  end

  defmodule MediaUploadRequest do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "MediaUploadRequest",
      type: :object,
      properties: %{
        files: %Schema{
          type: :array,
          items: %Schema{type: :string, format: :binary},
          description: "PNG, JPEG or WEBP images to upload.",
          example: ["(binary image data)"]
        }
      },
      required: [:files]
    })
  end

  defmodule MediaAsset do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "MediaAsset",
      type: :object,
      required: [
        :id,
        :filename,
        :content_type,
        :byte_size,
        :used,
        :url,
        :inserted_at
      ],
      properties: %{
        id: %Schema{type: :string, format: :uuid, example: "b04826cf-b841-49ff-9bce-e2cef80d63b2"},
        filename: %Schema{type: :string, example: "banner.png"},
        content_type: %Schema{type: :string, example: "image/png"},
        byte_size: %Schema{type: :integer, example: 204_950},
        used: %Schema{type: :boolean, example: false},
        used_at: %Schema{type: :string, format: :"date-time", nullable: true, example: nil},
        url: %Schema{
          type: :string,
          format: :uri,
          example: "https://api.example.com/api/media/stream/b04826cf-b841-49ff-9bce-e2cef80d63b2"
        },
        inserted_at: %Schema{type: :string, format: :"date-time", example: "2024-02-20T17:41:13Z"}
      }
    })
  end

  defmodule MediaUploadResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "MediaUploadResponse",
      type: :object,
      required: [:success, :media],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        media: %Schema{type: :array, items: MediaAsset.schema()}
      }
    })
  end

  defmodule MediaGetRequest do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "MediaGetRequest",
      type: :object,
      required: [:ids],
      properties: %{
        ids: %Schema{
          type: :array,
          items: %Schema{type: :string, format: :uuid},
          minItems: 1,
          example: ["b04826cf-b841-49ff-9bce-e2cef80d63b2"]
        }
      }
    })
  end

  defmodule MediaGetResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "MediaGetResponse",
      type: :object,
      required: [:success, :media, :missing_ids],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        media: %Schema{type: :array, items: MediaAsset.schema()},
        missing_ids: %Schema{
          type: :array,
          items: %Schema{type: :string, format: :uuid},
          example: []
        }
      }
    })
  end

  defmodule MediaSignedUrlResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "MediaSignedUrlResponse",
      type: :object,
      required: [:success, :url, :expires_in],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        url: %Schema{
          type: :string,
          format: :uri,
          example:
            "http://127.0.0.1:9000/elixir/b04826cf-b841-49ff-9bce-e2cef80d63b2.png?X-Amz-Algorithm=AWS4-HMAC-SHA256..."
        },
        expires_in: %Schema{type: :integer, example: 120}
      }
    })
  end

  defmodule GigCategory do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigCategory",
      type: :object,
      required: [:id, :key, :label],
      properties: %{
        id: %Schema{type: :string, format: :uuid, example: "5c2a8172-1ab2-4fdd-a595-6fbbf54f6ee1"},
        key: %Schema{type: :string, example: "milk"},
        label: %Schema{type: :string, example: "Milk"},
        description: %Schema{
          type: :string,
          nullable: true,
          example: "Fresh milk sourced directly from local farms."
        },
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          example: "2025-11-02T16:50:21"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          example: "2025-11-02T16:52:10"
        }
      }
    })
  end

  defmodule GigCategoryRequest do
    @moduledoc false
    example = %{"key" => "milk", "label" => "Milk", "description" => "Fresh milk items"}

    OpenApiSpex.schema(%Schema{
      title: "GigCategoryRequest",
      type: :object,
      required: [:key, :label],
      properties: %{
        key: %Schema{type: :string, example: "milk"},
        label: %Schema{type: :string, example: "Milk"},
        description: %Schema{
          type: :string,
          nullable: true,
          example: "Fresh milk items"
        }
      },
      example: example
    })
  end

  defmodule GigCategoryResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigCategoryResponse",
      type: :object,
      required: [:success, :category],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        category: GigCategory.schema()
      }
    })
  end

  defmodule GigCategoryListResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigCategoryListResponse",
      type: :object,
      required: [:success, :categories],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        categories: %Schema{type: :array, items: GigCategory.schema()}
      }
    })
  end

  defmodule GigType do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigType",
      type: :object,
      required: [:id, :key, :label, :category_id],
      properties: %{
        id: %Schema{type: :string, format: :uuid, example: "96aebcc4-61e6-4b37-a6da-8802e5910d0d"},
        key: %Schema{type: :string, example: "buffalo"},
        label: %Schema{type: :string, example: "Buffalo"},
        description: %Schema{
          type: :string,
          nullable: true,
          example: "Rich and creamy buffalo milk"
        },
        category_id: %Schema{
          type: :string,
          format: :uuid,
          example: "5c2a8172-1ab2-4fdd-a595-6fbbf54f6ee1"
        },
        inserted_at: %Schema{
          type: :string,
          format: :"date-time",
          example: "2025-11-02T16:50:21"
        },
        updated_at: %Schema{
          type: :string,
          format: :"date-time",
          example: "2025-11-02T16:52:10"
        }
      }
    })
  end

  defmodule GigTypeRequest do
    @moduledoc false
    example = %{
      "key" => "cow",
      "label" => "Cow",
      "description" => "Cow milk options",
      "category_id" => "5c2a8172-1ab2-4fdd-a595-6fbbf54f6ee1"
    }

    OpenApiSpex.schema(%Schema{
      title: "GigTypeRequest",
      type: :object,
      required: [:key, :label],
      properties: %{
        key: %Schema{type: :string, example: "cow"},
        label: %Schema{type: :string, example: "Cow"},
        description: %Schema{type: :string, nullable: true, example: "Cow milk options"},
        category_id: %Schema{
          type: :string,
          format: :uuid,
          nullable: true,
          description: "UUID of the category this type belongs to."
        },
        category_key: %Schema{
          type: :string,
          nullable: true,
          description: "Alternatively supply the category key."
        }
      },
      example: example
    })
  end

  defmodule GigTypeResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigTypeResponse",
      type: :object,
      required: [:success, :type],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        type: GigType.schema()
      }
    })
  end

  defmodule GigTypeListResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigTypeListResponse",
      type: :object,
      required: [:success, :types],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        types: %Schema{type: :array, items: GigType.schema()}
      }
    })
  end

  defmodule GigSeller do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigSeller",
      type: :object,
      required: [:name, :role, :location],
      properties: %{
        name: %Schema{type: :string, example: "Ahmed Dairy Services"},
        role: %Schema{
          type: :array,
          items: %Schema{type: :string},
          example: ["Shopkeeper", "Delivery Partner"]
        },
        location: %Schema{type: :string, example: "Gulshan-e-Iqbal, Karachi"}
      }
    })
  end

  defmodule GigAvailability do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigAvailability",
      type: :object,
      required: [:days, :timings],
      properties: %{
        days: %Schema{type: :string, example: "Mon - Sun"},
        timings: %Schema{type: :string, example: "5:00 AM – 9:00 AM"}
      }
    })
  end

  defmodule GigOrderLimits do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigOrderLimits",
      type: :object,
      required: [:min, :max],
      properties: %{
        min: %Schema{type: :string, example: "1 litre"},
        max: %Schema{type: :string, example: "20 litres"}
      }
    })
  end

  defmodule GigDeliveryCharges do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigDeliveryCharges",
      type: :object,
      properties: %{
        type: %Schema{type: :string, nullable: true, example: "flat"},
        amount: %Schema{type: :integer, nullable: true, example: 50},
        perKmAmount: %Schema{type: :integer, nullable: true, example: 20},
        freeAbove: %Schema{type: :integer, nullable: true, example: 2000}
      }
    })
  end

  defmodule GigDelivery do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigDelivery",
      type: :object,
      required: [:available],
      properties: %{
        available: %Schema{type: :boolean, example: true},
        type: %Schema{
          type: :string,
          nullable: true,
          enum: ["area-based", "distance-based"],
          example: "area-based"
        },
        areasCovered: %Schema{
          type: :array,
          items: %Schema{type: :string},
          nullable: true,
          example: ["Gulshan", "Johar", "Bahadurabad"]
        },
        radiusKm: %Schema{type: :integer, nullable: true, example: 8},
        charges: %Schema{anyOf: [GigDeliveryCharges.schema()], nullable: true}
      }
    })
  end

  defmodule GigSubscription do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigSubscription",
      type: :object,
      properties: %{
        available: %Schema{type: :boolean, example: true},
        type: %Schema{
          type: :string,
          nullable: true,
          enum: ["monthly", "weekly"],
          example: "monthly"
        },
        description: %Schema{type: :string, nullable: true},
        discountPercent: %Schema{type: :integer, nullable: true, example: 10},
        pricePerMonth: %Schema{type: :string, nullable: true, example: "Rs. 12,000 / month"},
        dailyQuantity: %Schema{type: :string, nullable: true, example: "2 litres/day"},
        notes: %Schema{type: :string, nullable: true}
      }
    })
  end

  defmodule Gig do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "Gig",
      type: :object,
      required: [
        :id,
        :title,
        :category,
        :type,
        :seller,
        :availability,
        :order_limits,
        :reviews,
        :review_count,
        :price,
        :delivery,
        :extras,
        :is_active
      ],
      properties: %{
        id: %Schema{type: :string, format: :uuid},
        title: %Schema{type: :string, example: "Fresh Cow Milk — Daily Home Delivery"},
        description: %Schema{
          type: :string,
          example: "Pure cow milk sourced from local dairy farms."
        },
        category: GigCategory.schema(),
        type: GigType.schema(),
        seller: GigSeller.schema(),
        availability: GigAvailability.schema(),
        order_limits: GigOrderLimits.schema(),
        reviews: %Schema{type: :string, example: "4.7 / 5"},
        review_count: %Schema{type: :integer, example: 250},
        price: %Schema{type: :string, example: "Rs. 220 / litre"},
        delivery: GigDelivery.schema(),
        subscription: %Schema{anyOf: [GigSubscription.schema()], nullable: true},
        extras: %Schema{
          type: :array,
          items: %Schema{type: :string},
          example: ["Glass bottles available", "UPI & COD"]
        },
        purity: %Schema{type: :string, nullable: true, example: "98.5%"},
        metadata: %Schema{
          type: :object,
          additionalProperties: true,
          nullable: true
        },
        is_active: %Schema{type: :boolean, example: true},
        inserted_at: %Schema{type: :string, format: :"date-time"},
        updated_at: %Schema{type: :string, format: :"date-time"}
      }
    })
  end

  defmodule GigRequest do
    @moduledoc false
    example = %{
      "title" => "Fresh Cow Milk — Daily Home Delivery",
      "category_key" => "milk",
      "type_key" => "cow",
      "description" => "Pure cow milk sourced from local dairy farms in Karachi.",
      "seller" => %{
        "name" => "Ahmed Dairy Services",
        "role" => ["Shopkeeper", "Delivery Partner"],
        "location" => "Gulshan-e-Iqbal, Karachi"
      },
      "availability" => %{"days" => "Mon - Sun", "timings" => "5:00 AM – 9:00 AM"},
      "order_limits" => %{"min" => "1 litre", "max" => "20 litres"},
      "reviews" => "4.7 / 5",
      "review_count" => 250,
      "price" => "Rs. 220 / litre",
      "delivery" => %{
        "available" => true,
        "type" => "area-based",
        "areasCovered" => ["Gulshan", "Johar"],
        "charges" => %{"type" => "flat", "amount" => 50, "freeAbove" => 2000}
      },
      "subscription" => %{
        "available" => true,
        "type" => "monthly",
        "description" => "Daily 2L supply with doorstep delivery.",
        "pricePerMonth" => "Rs. 12,000 / month",
        "dailyQuantity" => "2 litres/day",
        "discountPercent" => 10
      },
      "extras" => ["Glass bottles available", "UPI & COD"],
      "purity" => "98.5%",
      "metadata" => %{"note" => "Morning delivery only"}
    }

    OpenApiSpex.schema(%Schema{
      title: "GigRequest",
      type: :object,
      required: [:title],
      properties: %{
        title: %Schema{type: :string},
        description: %Schema{type: :string, nullable: true},
        category_id: %Schema{
          type: :string,
          format: :uuid,
          nullable: true,
          description: "Either provide category_id or category_key."
        },
        category_key: %Schema{
          type: :string,
          nullable: true,
          description: "Either provide category_key or category_id."
        },
        type_id: %Schema{
          type: :string,
          format: :uuid,
          nullable: true,
          description: "Either provide type_id or type_key."
        },
        type_key: %Schema{
          type: :string,
          nullable: true,
          description: "Either provide type_key or type_id."
        },
        seller: GigSeller.schema(),
        seller_name: %Schema{
          type: :string,
          nullable: true,
          description: "Alternative top-level field if not using nested seller object."
        },
        seller_roles: %Schema{
          type: :array,
          items: %Schema{type: :string},
          nullable: true,
          description: "Alternative top-level field."
        },
        seller_location: %Schema{
          type: :string,
          nullable: true,
          description: "Alternative top-level field."
        },
        availability: GigAvailability.schema(),
        availability_days: %Schema{type: :string, nullable: true},
        availability_timings: %Schema{type: :string, nullable: true},
        order_limits: GigOrderLimits.schema(),
        order_min: %Schema{type: :string, nullable: true},
        order_max: %Schema{type: :string, nullable: true},
        reviews: %Schema{type: :string, nullable: true},
        review_count: %Schema{type: :integer, nullable: true},
        price: %Schema{type: :string, nullable: true},
        delivery: GigDelivery.schema(),
        delivery_available: %Schema{type: :boolean, nullable: true},
        delivery_type: %Schema{type: :string, nullable: true},
        delivery_areas: %Schema{
          type: :array,
          items: %Schema{type: :string},
          nullable: true
        },
        delivery_radius_km: %Schema{type: :integer, nullable: true},
        delivery_charges_type: %Schema{type: :string, nullable: true},
        delivery_charges_amount: %Schema{type: :integer, nullable: true},
        delivery_charges_per_km_amount: %Schema{type: :integer, nullable: true},
        delivery_charges_free_above: %Schema{type: :integer, nullable: true},
        subscription: GigSubscription.schema(),
        subscription_available: %Schema{type: :boolean, nullable: true},
        subscription_type: %Schema{type: :string, nullable: true},
        subscription_description: %Schema{type: :string, nullable: true},
        subscription_discount_percent: %Schema{type: :integer, nullable: true},
        subscription_price_per_month: %Schema{type: :string, nullable: true},
        subscription_daily_quantity: %Schema{type: :string, nullable: true},
        subscription_notes: %Schema{type: :string, nullable: true},
        extras: %Schema{
          type: :array,
          items: %Schema{type: :string},
          nullable: true
        },
        purity: %Schema{type: :string, nullable: true},
        metadata: %Schema{type: :object, additionalProperties: true, nullable: true},
        is_active: %Schema{type: :boolean, nullable: true}
      },
      example: example
    })
  end

  defmodule GigResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigResponse",
      type: :object,
      required: [:success, :gig],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        gig: Gig.schema()
      }
    })
  end

  defmodule GigListResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "GigListResponse",
      type: :object,
      required: [:success, :gigs],
      properties: %{
        success: %Schema{type: :boolean, example: true},
        gigs: %Schema{type: :array, items: Gig.schema()}
      }
    })
  end

  defmodule GigFilterParams do
    @moduledoc false

    @doc """
    Returns reusable OpenAPI parameter specs for gig filtering endpoints.
    """
    @spec parameters() :: [Operation.parameter()]
    def parameters do
      [
        Operation.parameter(
          :category_id,
          :query,
          %Schema{type: :string, format: :uuid},
          "Filter by category ID."
        ),
        Operation.parameter(
          :type_id,
          :query,
          %Schema{type: :string, format: :uuid},
          "Filter by type ID."
        ),
        Operation.parameter(
          :title,
          :query,
          :string,
          "Case-insensitive match on gig title."
        ),
        Operation.parameter(:seller_name, :query, :string, "Filter by seller name."),
        Operation.parameter(:seller_location, :query, :string, "Filter by seller location."),
        Operation.parameter(
          :delivery_available,
          :query,
          :boolean,
          "When true, only gigs with delivery available are returned."
        ),
        Operation.parameter(
          :subscription_available,
          :query,
          :boolean,
          "When true, only gigs with subscription options are returned."
        ),
        Operation.parameter(:is_active, :query, :boolean, "Filter by activation status."),
        Operation.parameter(:review_count, :query, :integer, "Minimum review count."),
        Operation.parameter(
          :price,
          :query,
          :string,
          "Case-insensitive match against the price string."
        ),
        Operation.parameter(:purity, :query, :string, "Match against the purity descriptor.")
      ]
    end
  end

  defmodule HealthResponse do
    @moduledoc false
    OpenApiSpex.schema(%Schema{
      title: "HealthResponse",
      type: :string,
      example: "server is running"
    })
  end
end
