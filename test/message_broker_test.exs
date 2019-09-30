defmodule MessageBrokerTest do
  use ExUnit.Case

  import MessageBroker.ApplicationTestHelper

  describe "consumer" do
    test "initialize" do
      config = %{
        rabbitmq_user: "guest",
        rabbitmq_password: "guest",
        rabbitmq_host: "message-broker-rabbitmq",
        rabbitmq_exchange: "example_exchange",
        rabbitmq_queue: "example_queue",
        rabbitmq_subscribed_topics: ["test.test"],
        rabbitmq_message_handler: &MessageBroker.MessageHandlerMock.handle_message/2,
        rabbitmq_broadway_options: [],
        rabbitmq_retries_count: 3
      }

      assert {:ok, pid} = start_consumer(MyConsumer, config)
      assert is_pid(pid)

      stop_supervisor(pid)
    end
  end

  describe "publisher" do
    test "initialize" do
      config = %{
        repo: MessageBroker.Repo,
        rabbitmq_user: "guest",
        rabbitmq_password: "guest",
        rabbitmq_host: "message-broker-rabbitmq",
        rabbitmq_exchange: "example_exchange"
      }

      assert {:ok, pid} = start_publisher(MyPublisher, config)
      assert is_pid(pid)

      stop_supervisor(pid)
    end
  end
end
