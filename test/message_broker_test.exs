defmodule MessageBrokerTest do
  use ExUnit.Case

  describe "consumer" do
    test "initialize" do
      defmodule MyConsumer do
        use MessageBroker, as: :consumer
      end

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

      assert {:ok, pid} = MyConsumer.start_link(config: config)
      assert is_pid(pid)

      Process.exit(pid, :normal)
    end
  end

  describe "producer" do
    test "initialize" do
      defmodule MessageBrokerMock.Repo do
        use Ecto.Repo,
          otp_app: :message_broker,
          adapter: Ecto.Adapters.Postgres
      end

      defmodule MyPublisher do
        use MessageBroker, as: :publisher
      end

      config = %{
        repo: MessageBrokerMock.Repo,
        rabbitmq_user: "guest",
        rabbitmq_password: "guest",
        rabbitmq_host: "message-broker-rabbitmq",
        rabbitmq_exchange: "example_exchange"
      }

      assert {:ok, pid} = MyPublisher.start_link(config: config)
      assert is_pid(pid)

      Process.exit(pid, :normal)
    end
  end
end
