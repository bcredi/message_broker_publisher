# credo:disable-for-this-file
defmodule MessageBroker.ApplicationTestHelper do
  def start_consumer(module_name \\ MyConsumer, custom_config \\ %{}) do
    config =
      Map.merge(
        %{
          rabbitmq_user: "guest",
          rabbitmq_password: "guest",
          rabbitmq_host: "message-broker-rabbitmq",
          rabbitmq_exchange: "example_exchange",
          rabbitmq_queue: "example_queue",
          rabbitmq_subscribed_topics: ["test.test"],
          rabbitmq_message_handler: &MessageBroker.MessageHandlerMock.handle_message/2,
          rabbitmq_broadway_options: [],
          rabbitmq_retries_count: 3
        },
        custom_config
      )

    module_name.start_link(config: config)
  end

  def start_publisher(module_name \\ MyPublisher, custom_config \\ %{}, custom_repo \\ nil) do
    config =
      Map.merge(
        %{
          repo: custom_repo || MessageBroker.Repo,
          rabbitmq_user: "guest",
          rabbitmq_password: "guest",
          rabbitmq_host: "message-broker-rabbitmq",
          rabbitmq_exchange: "example_exchange"
        },
        custom_config
      )

    module_name.start_link(config: config)
  end

  def kill_application(pid), do: Process.exit(pid, :normal)
end

defmodule MyConsumer do
  use MessageBroker, as: :consumer, name: "Some"
end

defmodule MyPublisher do
  use MessageBroker, as: :publisher, name: "Some"
end
