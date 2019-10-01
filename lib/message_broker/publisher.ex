defmodule MessageBroker.Publisher do
  @moduledoc """
  RabbitMQ Publisher.

  This is a GenServer that keeps a connection open with the broker and know
  how publish messages to it.

  ## Examples

      iex> {:ok, _pid} = Publisher.start_link
      {:ok, #PID<0.105.0>}

      iex> Publisher.publish_event(%Event{event_name: "lead.created", payload: %{name: "mauricio"}})
      {:ok, :ok}

  ## Topics/Queues

  The *event_name* is used as topic/queue name to publish inside exchange.

  """

  use MessageBroker.RabbitmqServer, as: "Publisher"

  alias MessageBroker.Publisher.Event

  @impl GenServer
  def init(
        %{
          rabbitmq_user: user,
          rabbitmq_password: password,
          rabbitmq_host: host,
          rabbitmq_exchange: exchange
        } = config
      ) do
    {:ok, chan} = rabbitmq_connect(user, password, host)
    :ok = Exchange.topic(chan, exchange, durable: true)
    {:ok, [config: config, channel: chan]}
  end

  @doc """
  Publish event to rabbitmq exchange.
  """
  @callback publish_event(Event.t()) :: {:ok, :ok} | {:error, reason :: :blocked | :closed}
  def publish_event(%Event{event_name: topic} = event) do
    case GenServer.call(__MODULE__, {:publish, topic, build_event_payload(event)}) do
      :ok -> {:ok, :ok}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Build the binary payload to publish in the rabbitmq exchanges.

  ## Examples

      iex> build_event_payload(%Event{event_name: "my_event", payload: %{id: "123"}})
      "{\"event\":\"my_event\",\"payload\":{\"id\":\"123\"},\"timestamp\":\"2019-09-25T19:54:20.464057Z\"}"

  """
  def build_event_payload(%Event{event_name: topic, payload: payload}) do
    event = %{
      event: topic,
      timestamp: get_timestamp(),
      payload: payload
    }

    Jason.encode!(event)
  end

  defp get_timestamp do
    {:ok, dt} = DateTime.now("Etc/UTC")
    DateTime.to_iso8601(dt, :extended)
  end

  @impl GenServer
  def handle_call(
        {:publish, topic, payload},
        _from,
        [config: %{rabbitmq_exchange: exchange}, channel: channel] = state
      ) do
    {:reply, Basic.publish(channel, exchange, topic, payload, persistent: true), state}
  end
end
