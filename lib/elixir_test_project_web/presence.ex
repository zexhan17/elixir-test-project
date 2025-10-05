defmodule ElixirTestProjectWeb.Presence do
  use Phoenix.Presence,
    otp_app: :elixir_test_project,
    pubsub_server: ElixirTestProject.PubSub
end
