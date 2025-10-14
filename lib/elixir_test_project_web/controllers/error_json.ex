defmodule ElixirTestProjectWeb.ErrorJSON do
  @moduledoc """
  Consistent JSON errors for crashes, missing routes, or unhandled exceptions.
  """

  def render("404.json", _assigns), do: %{error: "not_found"}
  def render("500.json", _assigns), do: %{error: "internal_server_error"}
  def render("403.json", _assigns), do: %{error: "forbidden"}
  def render("401.json", _assigns), do: %{error: "unauthorized"}

  # Default fallback
  def render(template, _assigns) do
    %{error: Phoenix.Controller.status_message_from_template(template)}
  end
end
