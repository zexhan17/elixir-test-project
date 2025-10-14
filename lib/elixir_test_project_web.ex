defmodule ElixirTestProjectWeb do
  @moduledoc """
  The entrypoint for defining your web interface — controllers, components, channels, etc.

  Example usage:

      use ElixirTestProjectWeb, :controller
      use ElixirTestProjectWeb, :api_controller
      use ElixirTestProjectWeb, :html
  """

  def static_paths, do: ~w(assets fonts images favicon.ico robots.txt)

  # --- Router setup ---
  def router do
    quote do
      use Phoenix.Router, helpers: false

      import Plug.Conn
      import Phoenix.Controller
    end
  end

  # --- Channel setup ---
  def channel do
    quote do
      use Phoenix.Channel
    end
  end

  # --- Standard (HTML or mixed) controller ---
  def controller do
    quote do
      use Phoenix.Controller, formats: [:html, :json]
      use Gettext, backend: ElixirTestProjectWeb.Gettext

      import Plug.Conn
      unquote(verified_routes())
    end
  end

  # --- JSON API controller (with automatic fallback) ---
  def api_controller do
    quote do
      use Phoenix.Controller, formats: [:json]
      use Gettext, backend: ElixirTestProjectWeb.Gettext

      import Plug.Conn
      unquote(verified_routes())

      action_fallback ElixirTestProjectWeb.FallbackController
    end
  end

  # --- Verified routes (path helpers) ---
  def verified_routes do
    quote do
      use Phoenix.VerifiedRoutes,
        endpoint: ElixirTestProjectWeb.Endpoint,
        router: ElixirTestProjectWeb.Router,
        statics: ElixirTestProjectWeb.static_paths()
    end
  end

  @doc """
  When used, dispatch to the appropriate controller, channel, etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
