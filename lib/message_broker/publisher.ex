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

  use AMQP
  use GenServer

  require Logger

  alias AMQP.Basic
  alias MessageBroker.Event

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @callback publish_event(Event.t()) :: {:ok, :ok} | {:error, :topic_not_allowed}
  def publish_event(%Event{event_name: topic, payload: payload}) do
    event = %{
      event: topic,
      timestamp: get_timestamp(),
      payload: payload
    }

    publish(topic, Jason.encode!(event))
  end

  defp publish(topic, payload) do
    allowed_topics = MessageBroker.get_config(:rabbitmq_topics)

    if topic in allowed_topics do
      :ok = GenServer.cast(__MODULE__, {:publish, topic, payload})
      {:ok, :ok}
    else
      {:error, :topic_not_allowed}
    end
  end

  defp get_timestamp do
    {:ok, dt} = DateTime.now("Etc/UTC")
    DateTime.to_iso8601(dt, :extended)
  end

  defp rabbitmq_connect do
    Logger.info("Connecting to RabbitMQ (Publisher).")

    case open_connection() do
      {:ok, conn} ->
        # Get notifications when the connection goes down
        Process.monitor(conn.pid)
        {:ok, chan} = Channel.open(conn)
        :ok = Exchange.topic(chan, exchange(), durable: true)
        {:ok, chan}

      {:error, error} ->
        # Reconnection loop
        Logger.info("Reconnecting to RabbitMQ (Publisher).\nReason: #{inspect(error)}")
        Process.sleep(10_000)
        rabbitmq_connect()
    end
  end

  defp open_connection do
    user = MessageBroker.get_config(:rabbitmq_user)
    password = MessageBroker.get_config(:rabbitmq_password)
    host = MessageBroker.get_config(:rabbitmq_host)

    Connection.open("amqp://#{user}:#{password}@#{host}")
  end

  @impl GenServer
  def init(_opts) do
    rabbitmq_connect()
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, :shutdown}, _state) do
    File.touch("rabbit_error")
    Logger.info("Publisher connection has died (:EXIT), therefore I have to die as well.")
    Process.exit(self(), :kill)
  end

  @impl GenServer
  def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
    File.touch("rabbit_error")

    Logger.error("""
    Publisher connection has died (:DOWN), therefore I have to die as well.\n
    Reason: #{inspect(reason)}
    """)

    Process.exit(self(), :kill)
  end

  @impl GenServer
  def handle_cast({:publish, topic, payload}, channel) do
    :ok = Basic.publish(channel, exchange(), topic, payload, persistent: true)
    {:noreply, channel}
  end

  defp exchange, do: MessageBroker.get_config(:rabbitmq_exchange)
end
