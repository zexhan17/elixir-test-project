defmodule ElixirTestProject.Repo do
  use Ecto.Repo,
    otp_app: :elixir_test_project,
    adapter: Ecto.Adapters.SQLite3
end
