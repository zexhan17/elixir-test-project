defmodule ElixirTestProjectWeb.HealthController do
  use ElixirTestProjectWeb, :controller
  action_fallback ElixirTestProjectWeb.FallbackController

  def index(conn, _params) do
    text(conn, "server is running")
  end
end
