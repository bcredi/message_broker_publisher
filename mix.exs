defmodule MessageBroker.MixProject do
  use Mix.Project

  def project do
    [
      app: :message_broker,
      version: "0.1.4",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.1"},
      {:postgrex, ">= 0.0.0"},
      {:jason, "~> 1.0"},
      {:broadway, "~> 0.4.0"},
      {:broadway_rabbitmq, "~> 0.4.0"},
      {:amqp, "~> 1.3"},
      {:credo, "~> 1.4.0", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.0.0-rc.7", only: [:dev], runtime: false},
      {:mox, "~> 0.5", only: :test},
      {:faker, "~> 0.13", only: :test}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_env), do: ["lib"]
end
