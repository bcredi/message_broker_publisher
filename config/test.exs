import Config

config :message_broker, ecto_repos: [MessageBroker.Repo]

config :message_broker, MessageBroker.Repo,
  username: System.get_env("PG_USERNAME") || "postgres",
  password: System.get_env("PG_PASSWORD") || "postgres",
  hostname: System.get_env("PG_HOST") || "localhost",
  port: System.get_env("PG_PORT") || 5432,
  database: System.get_env("PG_DATABASE") || "broker_test",
  pool: Ecto.Adapters.SQL.Sandbox
