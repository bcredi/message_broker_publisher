defmodule MessageBroker.ConsumerTest do
  use ExUnit.Case

  import MessageBroker.ApplicationTestHelper
  import Mox

  alias AMQP.{Basic, Channel, Connection, Queue}
  alias Broadway.Message
  alias MessageBroker.MessageHandlerMock

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
          rabbitmq_subscribed_topics: ["test.test"],
          rabbitmq_consumer_message_handler: &MessageBroker.MessageHandlerMock.handle_message/2,
          rabbitmq_retries_count: 3
        })

      {:ok, %{pid: pid}}
    end

    @queue "example_queue"
    @exchange "test_exchange"

    test "sucessful consume an event", %{pid: pid} do
      json = "{\"key\":\"value\"}"
      metadata = %{headers: %{"key" => "value"}}
      message = %Message{data: json, metadata: metadata, acknowledger: nil}

      decoded_json = Jason.decode!(json)
      expect(MessageHandlerMock, :handle_message, 1, fn ^decoded_json, ^metadata -> :ok end)

      assert ^message =
               MyConsumer.handle_message(nil, message, %{
                 message_handler: &MessageBroker.MessageHandlerMock.handle_message/2,
                 message_retrier_name: MessageBroker.Internal.SomeMessageRetrier
               })

      stop_supervisor(pid)
    end

    test "fail to consume an event and retries until dead-letter", %{pid: pid} do
      message_payload = "{}"

      {:ok, chan} = open_rabbitmq_connection()
      :ok = send_rabbitmq_message(chan, "test.test", message_payload)

      # MessageHandler always fail to trigger retries and dead-letter queue
      expect(MessageHandlerMock, :handle_message, 4, fn _, _ -> {:error, "some error"} end)

      # Wait exponential time for 3 retry counts (1s + 4s + 9s =~ 15s)
      Process.sleep(15_000)
      stop_supervisor(pid)

      # The message is in dead-letter queue
      assert {:ok, payload, %{headers: headers}} = get_rabbitmq_message(chan, "#{@queue}_error")

      # The message payload is the same
      assert payload == message_payload

      # x-death headers must contain the original fail and 3 subsequent retry fails
      assert death_count(headers) == 4
    end

    defp open_rabbitmq_connection do
      {:ok, conn} =
        Connection.open(
          username: "guest",
          password: "guest",
          host: "message-broker-rabbitmq",
          virtual_host: "/"
        )

      {:ok, _chan} = Channel.open(conn)
    end

    defp send_rabbitmq_message(channel, topic, payload) do
      Queue.bind(channel, @queue, @exchange, routing_key: topic)
      :ok = Basic.publish(channel, @exchange, topic, payload, persistent: true)
    end

    defp get_rabbitmq_message(channel, queue) do
      {:ok, _payload, _meta} = AMQP.Basic.get(channel, queue)
    end

    defp death_count(headers) do
      {_xdeath, _, retries} = Enum.find(headers, fn {header, _, _} -> header == "x-death" end)

      Enum.reduce(retries, 0, fn {:table, fields}, acc ->
        {"count", _, count} = Enum.find(fields, fn {field, _t, _v} -> field == "count" end)
        acc + count
      end)
    end
  end
end
