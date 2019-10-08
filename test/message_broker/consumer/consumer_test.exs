defmodule MessageBroker.ConsumerTest do
  use ExUnit.Case

  import MessageBroker.ApplicationTestHelper
  import Mox

  alias AMQP.{Basic, Channel, Connection, Queue}
  alias Broadway.Message
  alias MessageBroker.{Consumer, MessageHandlerMock}
  alias MessageBroker.Consumer.MessageRetrier

  setup :verify_on_exit!
  setup :set_mox_global

  describe "#handle_message/3" do
    setup do
      {:ok, pid} =
        start_consumer(MyConsumer, %{
          rabbitmq_host: "message-broker-rabbitmq",
          rabbitmq_user: "guest",
          rabbitmq_password: "guest",
          rabbitmq_exchange: "test_exchange",
          rabbitmq_consumer_message_handler: &MessageBroker.MessageHandlerMock.handle_message/2
        })

      {:ok, %{pid: pid}}
    end

    test "sucessful consume an event", %{pid: pid} do
      json = "{\"key\":\"value\"}"
      metadata = %{headers: %{"key" => "value"}}
      message = %Message{data: json, metadata: metadata, acknowledger: nil}

      decoded_json = Jason.decode!(json)
      expect(MessageHandlerMock, :handle_message, 1, fn ^decoded_json, ^metadata -> :ok end)

      assert ^message = MyConsumer.handle_message(nil, message, nil)

      kill_application(pid)
      # Supervisor.terminate_child(MessageBrokerConsumer.Broadway.Supervisor, pid)
    end

    test "fail to consume an event and retries until dead-letter", %{pid: pid} do
      {:ok, retrier_pid} =
        MessageRetrier.start_link(%{
          rabbitmq_host: "message-broker-rabbitmq",
          rabbitmq_user: "guest",
          rabbitmq_password: "guest",
          rabbitmq_exchange: "test_exchange",
          rabbitmq_queue: "example_queue",
          rabbitmq_retries_count: 3
        })

      send_rabbitmq_message("test.test", "{}")

      expect(MessageHandlerMock, :handle_message, 4, fn _, _ -> {:error, "some error"} end)

      Process.sleep(15_000)
      kill_application(pid)
      # Supervisor.terminate_child(MessageBrokerConsumer.Broadway.Supervisor, pid)
      # Supervisor.terminate_child(MessageBroker.Supervisor, retrier_pid)
    end

    defp send_rabbitmq_message(topic, payload) do
      {:ok, conn} =
        Connection.open(
          username: "guest",
          password: "guest",
          host: "message-broker-rabbitmq",
          virtual_host: "/"
        )

      {:ok, chan} = Channel.open(conn)

      queue = "example_queue"
      exchange = "test_exchange"
      Queue.bind(chan, queue, exchange, routing_key: topic)
      :ok = Basic.publish(chan, exchange, topic, payload, persistent: true)
    end
  end
end
