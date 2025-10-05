defmodule ElixirTestProjectWeb.HealthController do
  use ElixirTestProjectWeb, :controller

  def index(conn, _params) do
    text(conn, "server is running")
  end
end
