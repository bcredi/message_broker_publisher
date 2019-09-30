defmodule MessageBroker.Consumer.MessageRetrier do
  @moduledoc """
  Retries failed messages in exponential time until rejects it.
  """

  use MessageBroker.RabbitmqServer, as: "MessageRetrier"

  alias AMQP.Basic

  @impl GenServer
  def init(_opts), do: rabbitmq_connect()

  @doc """
  Retry a message if possible.
  """
  @callback retry_message(map()) :: {:ok, :message_retried} | {:error, :message_retries_expired}
  def retry_message(message, headers) do
    case GenServer.call(__MODULE__, {:retry, message, headers}) do
      :ok -> {:ok, :message_retried}
      error -> error
    end
  end

  @impl GenServer
  def handle_call({:retry, message, headers}, _from, channel) do
    {:reply, handle_failed_message(message, headers, channel), channel}
  end

  defp handle_failed_message(message, headers, channel) do
    retries_count = death_count(headers)

    if retries_count < max_retries() do
      delay = exponential_delay_milliseconds(retries_count)
      routing_key = "#{queue()}.#{delay}"

      {:ok, %{queue: retry_queue}} = create_retry_queue(channel, delay)
      :ok = Queue.bind(channel, retry_queue, exchange(), routing_key: routing_key)

      Basic.publish(channel, exchange(), routing_key, message, headers: headers, persistent: true)
    else
      {:error, :message_retries_expired}
    end
  end

  defp max_retries, do: MessageBroker.get_config(:rabbitmq_consumer_retries_count)

  defp queue, do: MessageBroker.get_config(:rabbitmq_consumer_queue)

  defp exchange, do: MessageBroker.get_config(:rabbitmq_exchange)

  defp death_count(:undefined), do: 0

  defp death_count(headers) do
    {_, _, tables} = Enum.find(headers, {"x-death", :long, []}, &({"x-death", _, _} = &1))

    Enum.reduce(tables, 0, fn {:table, values}, acc ->
      {_, _, count} = Enum.find(values, {"count", :long, 0}, &({"count", _, _} = &1))
      acc + count
    end)
  end

  defp exponential_delay_milliseconds(retries), do: pow(retries + 1, 2) * 1000

  defp pow(base, 1), do: base
  defp pow(base, exp), do: base * pow(base, exp - 1)

  defp create_retry_queue(channel, delay) do
    Queue.declare(channel, "#{queue()}.retry.#{delay}",
      durable: true,
      arguments: [
        {"x-dead-letter-exchange", :longstr, ""},
        {"x-dead-letter-routing-key", :longstr, queue()},
        {"x-message-ttl", :long, delay},
        {"x-expires", :long, delay * 2}
      ]
    )
  end
end
