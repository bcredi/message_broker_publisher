import Config

config :message_broker,
  rabbitmq_consumer_enabled: false,
  rabbitmq_publisher_enabled: false,
  rabbitmq_host: "message-broker-rabbitmq",
  rabbitmq_user: "guest",
  rabbitmq_password: "guest",
  rabbitmq_exchange: "test_exchange",
  rabbitmq_consumer_message_handler: &MessageBroker.MessageHandlerMock.handle_message/2
