# credo:disable-for-this-file
defmodule MessageBroker.ApplicationTestHelper do
  alias AMQP.{Basic, Channel, Connection, Queue}

  def default_exchange, do: "example_exchange"
  def default_queue, do: "example_queue"

  def start_consumer(module_name \\ MyConsumer, custom_config \\ %{}) do
    config = Map.merge(consumer_default_config(), custom_config)
    module_name.start_link(config: config)
  end

  def consumer_default_config do
    %{
      rabbitmq_user: "guest",
      rabbitmq_password: "guest",
      rabbitmq_host: "message-broker-rabbitmq",
      rabbitmq_exchange: default_exchange(),
      rabbitmq_queue: default_queue(),
      rabbitmq_subscribed_topics: ["test.test"],
      rabbitmq_message_handler: &MessageBroker.MessageHandlerMock.handle_message/2,
      rabbitmq_broadway_options: [],
      rabbitmq_retries_count: 3
    }
  end

  def start_publisher(module_name \\ MyPublisher, custom_config \\ %{}, custom_repo \\ nil) do
    config = Map.merge(publisher_default_config(custom_repo), custom_config)
    module_name.start_link(config: config)
  end

  def publisher_default_config(repo) do
    %{
      repo: repo || MessageBroker.Repo,
      rabbitmq_user: "guest",
      rabbitmq_password: "guest",
      rabbitmq_host: "message-broker-rabbitmq",
      rabbitmq_exchange: default_exchange()
    }
  end

  def stop_supervisor(pid), do: Supervisor.stop(pid, :normal)

  def open_rabbitmq_connection do
    {:ok, conn} =
      Connection.open(
        username: "guest",
        password: "guest",
        host: "message-broker-rabbitmq",
        virtual_host: "/"
      )

    {:ok, _chan} = Channel.open(conn)
  end

  def send_rabbitmq_message(channel, exchange, queue, topic, payload) do
    Queue.bind(channel, queue, exchange, routing_key: topic)
    :ok = Basic.publish(channel, exchange, topic, payload, persistent: true)
  end

  def get_rabbitmq_message(channel, queue) do
    {:ok, _payload, _meta} = AMQP.Basic.get(channel, queue, no_ack: true)
  end

  def message_death_count(headers) do
    {_, _, tables} = Enum.find(headers, {"x-death", :long, []}, &({"x-death", _, _} = &1))

    Enum.reduce(tables, 0, fn {:table, values}, acc ->
      {_, _, count} = Enum.find(values, {"count", :long, 0}, &({"count", _, _} = &1))
      acc + count
    end)
  end
end

defmodule MyConsumer do
  use MessageBroker, as: :consumer
end

defmodule MyPublisher do
  use MessageBroker, as: :publisher
end
