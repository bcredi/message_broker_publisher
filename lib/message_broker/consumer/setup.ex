defmodule MessageBroker.Consumer.Setup do
  @moduledoc """
  Initial setup for MessageBrokerConsumer.

  Adds default exchange and queues for this consumer.
  """

  use AMQP

  require Logger

  @doc """
  Initialize MessageBrokerConsumer in RabbitMQ server.
  """
  def init do
    Logger.info("Connecting to RabbitMQ to setup topics for queue.")

    case rabbitmq_connection() do
      {:ok, conn} ->
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan)

      {:error, error} ->
        Logger.error(
          "Reconnecting to RabbitMQ to setup topics for queue.\nReason: #{inspect(error)}"
        )

        Process.sleep(10_000)
        init()
    end
  end

  defp rabbitmq_connection do
    Connection.open(
      username: MessageBroker.get_config(:rabbitmq_user),
      password: MessageBroker.get_config(:rabbitmq_password),
      host: MessageBroker.get_config(:rabbitmq_host),
      virtual_host: "/"
    )
  end

  defp setup_queue(chan) do
    exchange = MessageBroker.get_config(:rabbitmq_exchange)
    subscribed_topics = MessageBroker.get_config(:rabbitmq_consumer_subscribed_topics)
    queue = MessageBroker.get_config(:rabbitmq_consumer_queue)
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
  end
end
