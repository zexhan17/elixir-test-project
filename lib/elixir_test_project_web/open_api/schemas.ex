defmodule ElixirTestProjectWeb.ApiSchemas do
  @moduledoc """
  Centralised OpenAPI schema definitions reused across controller operations.
  """

  alias OpenApiSpex.Schema
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
            "http://127.0.0.1:9000/elixir/uploads/2024-02-20/b04826cf-b841-49ff-9bce-e2cef80d63b2.png?X-Amz-Algorithm=AWS4-HMAC-SHA256..."
        },
        expires_in: %Schema{type: :integer, example: 120}
      }
    })
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
