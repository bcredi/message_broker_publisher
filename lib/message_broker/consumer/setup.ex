defmodule MessageBroker.Consumer.Setup do
  @moduledoc """
  Initial setup for Consumer.

  Adds default exchange, queues and its topics for this consumer.
  """

  use AMQP

  require Logger

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
          rabbitmq_subscribed_topics: subscribed_topics
        } = config
      ) do
    Logger.info("Connecting to RabbitMQ to setup topics for queue.")

    case rabbitmq_connection(user, password, host) do
      {:ok, conn} ->
        {:ok, chan} = Channel.open(conn)
        setup_queue(chan, exchange, queue, subscribed_topics)

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

  defp setup_queue(chan, exchange, queue, subscribed_topics) do
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
