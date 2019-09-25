import Config

config :message_broker,
  rabbitmq_host: "localhost",
  rabbitmq_user: "guest",
  rabbitmq_password: "guest",
  rabbitmq_exchange: "test_exchange"
