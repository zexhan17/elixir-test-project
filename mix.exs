defmodule ElixirTestProject.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_test_project,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      listeners: listeners(),
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {ElixirTestProject.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  defp listeners do
    if Mix.env() in [:dev, :test] do
      [Phoenix.CodeReloader]
    else
      []
    end
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.8.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:ecto_sqlite3, ">= 0.0.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:pbkdf2_elixir, "~> 1.3"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.26"},
      {:jason, "~> 1.2"},
      {:joken, "~> 2.6"},
      {:cors_plug, "~> 3.0"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:dotenvy, "~> 1.0.0"},
      {:open_api_spex, "~> 3.18"},
      # Core file upload abstraction
      {:waffle, "~> 1.1"},
      # If you want to store file refs in Ecto
      {:waffle_ecto, "~> 0.0.12"},
      # AWS/MinIO client
      {:ex_aws, "~> 2.6"},
      # S3-specific commands
      {:ex_aws_s3, "~> 2.5"},
      # HTTP client
      {:hackney, "~> 1.25"},
      # XML parser required by ExAws
      {:sweet_xml, "~> 0.7.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
