defmodule MessageBroker.ConsumerTest do
  use ExUnit.Case

  import Mox

  alias AMQP.{Basic, Channel, Connection, Queue}
  alias Broadway.Message
  alias MessageBroker.{Consumer, MessageHandlerMock}
  alias MessageBroker.Consumer.MessageRetrier

  setup :verify_on_exit!
  setup :set_mox_global

  describe "#handle_message/3" do
    test "sucessful consume an event" do
      {:ok, pid} = Consumer.start_link(nil)

      json = "{\"key\":\"value\"}"
      metadata = %{headers: %{"key" => "value"}}
      message = %Message{data: json, metadata: metadata, acknowledger: nil}

      decoded_json = Jason.decode!(json)
      expect(MessageHandlerMock, :handle_message, 1, fn ^decoded_json, ^metadata -> :ok end)

      assert ^message = Consumer.handle_message(nil, message, nil)

      Supervisor.terminate_child(MessageBrokerConsumer.Broadway.Supervisor, pid)
    end

    test "fail to consume an event and retries until dead-letter" do
      {:ok, pid} = Consumer.start_link(nil)
      {:ok, retrier_pid} = MessageRetrier.start_link(nil)

      send_rabbitmq_message("test.test", "{}")

      expect(MessageHandlerMock, :handle_message, 4, fn _, _ -> {:error, "some error"} end)

      Process.sleep(15_000)
      Supervisor.terminate_child(MessageBrokerConsumer.Broadway.Supervisor, pid)
      # Supervisor.terminate_child(MessageBroker.Supervisor, retrier_pid)
    end

    defp send_rabbitmq_message(topic, payload) do
      {:ok, conn} =
        Connection.open(
          username: MessageBroker.get_config(:rabbitmq_user),
          password: MessageBroker.get_config(:rabbitmq_password),
          host: MessageBroker.get_config(:rabbitmq_host),
          virtual_host: "/"
        )

      {:ok, chan} = Channel.open(conn)

      queue = MessageBroker.get_config(:rabbitmq_consumer_queue)
      exchange = MessageBroker.get_config(:rabbitmq_exchange)
      Queue.bind(chan, queue, exchange, routing_key: topic)
      :ok = Basic.publish(chan, exchange, topic, payload, persistent: true)
    end
  end
end
