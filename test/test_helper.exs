ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ElixirTestProject.Repo, :manual)

# Load test support helpers (ConnCase, etc.)
Path.wildcard(Path.join(__DIR__, "support/**/*.exs"))
|> Enum.each(&Code.require_file/1)
