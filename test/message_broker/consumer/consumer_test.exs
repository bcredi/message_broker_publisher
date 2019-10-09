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
    @queue "example_queue"
    @exchange "test_exchange"
    @topic "test.test"

    setup do
      {:ok, pid} =
        start_consumer(MyConsumer, %{
          rabbitmq_host: "message-broker-rabbitmq",
          rabbitmq_user: "guest",
          rabbitmq_password: "guest",
          rabbitmq_exchange: "test_exchange",
          rabbitmq_subscribed_topics: [@topic],
          rabbitmq_consumer_message_handler: &MessageBroker.MessageHandlerMock.handle_message/2,
          rabbitmq_retries_count: 3
        })

      {:ok, %{pid: pid}}
    end

    test "sucessfully consume an event", %{pid: pid} do
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
      message_payload = "{\"test\": \"#{Faker.Lorem.paragraph(3)}\"}"

      {:ok, chan} = open_rabbitmq_connection()
      :ok = send_rabbitmq_message(chan, @topic, message_payload)

      # MessageHandler always fail to trigger retries and dead-letter queue
      expect(MessageHandlerMock, :handle_message, 4, fn payload, _ ->
        assert payload == Jason.decode!(message_payload)
        {:error, "some error"}
      end)

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
      {:ok, _payload, _meta} = AMQP.Basic.get(channel, queue, no_ack: true)
    end

    defp death_count(headers) do
      {_, _, tables} = Enum.find(headers, {"x-death", :long, []}, &({"x-death", _, _} = &1))

      Enum.reduce(tables, 0, fn {:table, values}, acc ->
        {_, _, count} = Enum.find(values, {"count", :long, 0}, &({"count", _, _} = &1))
        acc + count
      end)
    end
  end
end
