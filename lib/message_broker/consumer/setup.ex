defmodule MessageBroker.Consumer.Setup do
  @moduledoc """
  Initial setup for Consumer.

  Adds default exchange, queues and its topics for this consumer.
  """

  use AMQP

  require Logger

  alias MessageBroker.Consumer.MessageRetrierHelper

  @doc """
  Initialize Consumer in RabbitMQ server.
  """
  def init(
        %{
          rabbitmq_user: user,
          rabbitmq_password: password,
          rabbitmq_host: host,
          rabbitmq_exchange: exchange,
          rabbitmq_queue: queue,
          rabbitmq_subscribed_topics: subscribed_topics,
          rabbitmq_retries_count: retries_count
        } = config
      ) do
    Logger.info("Connecting to RabbitMQ to setup topics for queue.")

    case rabbitmq_connection(user, password, host) do
      {:ok, conn} ->
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan, exchange, queue, subscribed_topics, retries_count)

      {:error, error} ->
        Logger.error(
          "Reconnecting to RabbitMQ to setup topics for queue.\nReason: #{inspect(error)}"
        )

        Process.sleep(10_000)
        init(config)
    end
  end

  defp rabbitmq_connection(user, password, host) do
    Connection.open(username: user, password: password, host: host, virtual_host: "/")
  end

  defp setup_queue(chan, exchange, queue, subscribed_topics, retries_count) do
    queue_error = "#{queue}_error"

    {:ok, _} = Queue.declare(chan, queue_error, durable: true)

    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} =
      Queue.declare(chan, queue,
        durable: true,
        arguments: [
          {"x-dead-letter-exchange", :longstr, ""},
          {"x-dead-letter-routing-key", :longstr, queue_error}
        ]
      )

    :ok = Exchange.topic(chan, exchange, durable: true)

    for topic <- subscribed_topics do
      :ok = Queue.bind(chan, queue, exchange, routing_key: topic)
    end

    create_retry_queues(retries_count, chan, exchange, queue)
  end

  defp create_retry_queues(retries_count, channel, exchange, queue)

  defp create_retry_queues(retries_count, _channel, _exchange, _queue) when retries_count < 1,
    do: :ok

  defp create_retry_queues(retries_count, channel, exchange, queue) when retries_count > 0 do
    Enum.each(1..retries_count, fn count ->
      delay = MessageRetrierHelper.exponential_delay_milliseconds(count - 1)
      create_retry_queue(channel, exchange, queue, delay)
    end)
  end

  defp create_retry_queue(channel, exchange, queue, delay) do
    {:ok, %{queue: retry_queue}} =
      Queue.declare(channel, "#{queue}.retry.#{delay}",
        durable: true,
        arguments: [
          {"x-dead-letter-exchange", :longstr, ""},
          {"x-dead-letter-routing-key", :longstr, queue},
          {"x-message-ttl", :long, delay}
        ]
      )

    routing_key = MessageRetrierHelper.routing_key(queue, delay)
    :ok = Queue.bind(channel, retry_queue, exchange, routing_key: routing_key)
  end
end
