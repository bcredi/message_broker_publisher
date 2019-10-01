defmodule MessageBroker.Consumer.MessageRetrier do
  @moduledoc """
  Retries failed messages in exponential time until rejects it.
  """

  use MessageBroker.RabbitmqServer, as: "MessageRetrier"

  alias AMQP.Basic

  @impl GenServer
  def init(
        %{
          rabbitmq_user: user,
          rabbitmq_password: password,
          rabbitmq_host: host,
          rabbitmq_exchange: _exchange,
          rabbitmq_queue: _queue,
          rabbitmq_retries_count: _retries
        } = config
      ) do
    {:ok, chan} = rabbitmq_connect(user, password, host)
    {:ok, [config: config, channel: chan]}
  end

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
  def handle_call({:retry, message, headers}, _from, [config: config, channel: channel] = state) do
    {:reply, handle_failed_message(message, headers, channel, config), state}
  end

  defp handle_failed_message(message, headers, channel, %{
         rabbitmq_exchange: exchange,
         rabbitmq_queue: queue,
         rabbitmq_retries_count: max_retries
       }) do
    retries_count = death_count(headers)

    if retries_count < max_retries do
      delay = exponential_delay_milliseconds(retries_count)
      routing_key = "#{queue}.#{delay}"

      {:ok, %{queue: retry_queue}} = create_retry_queue(channel, queue, delay)
      :ok = Queue.bind(channel, retry_queue, exchange, routing_key: routing_key)

      Basic.publish(channel, exchange, routing_key, message, headers: headers, persistent: true)
    else
      {:error, :message_retries_expired}
    end
  end

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

  defp create_retry_queue(channel, queue, delay) do
    Queue.declare(channel, "#{queue}.retry.#{delay}",
      durable: true,
      arguments: [
        {"x-dead-letter-exchange", :longstr, ""},
        {"x-dead-letter-routing-key", :longstr, queue},
        {"x-message-ttl", :long, delay},
        {"x-expires", :long, delay * 2}
      ]
    )
  end
end
