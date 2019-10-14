defmodule MessageBroker do
  @moduledoc ~S"""
  MessageBroker aims to consume and publish events.

  You'll need to create a module, use MessageBroker as :consumer or :publisher,
  and configure it in your application start_link.

  ## Creating a Consumer

  To create a consumer, you'll need to create a module like this:

      defmodule MyConsumer do
        use MessageBroker, as: :consumer
      end

  Then create a message handler for the consumer:

      defmodule MyMessageHandler do
        def handle_message(message, _message_metadata) do
          case process_message(message) do
            {:ok, :message_consumed} -> :ok
            error -> error
        end
      end

  Then add your module in a Supervisor (e.g. in your Application Supervisor) and configure it:

      config = %{
        rabbitmq_user: "guest",
        rabbitmq_password: "guest",
        rabbitmq_host: "localhost",
        rabbitmq_exchange: "example_exchange",
        rabbitmq_queue: "example_queue",
        rabbitmq_subscribed_topics: ["test.topic1", "test.topic2"],
        rabbitmq_message_handler: &MyMessageHandler.handle_message/2,
        rabbitmq_broadway_options: [],
        rabbitmq_retries_count: 3
      }

      children = [
        {MyConsumer, [config: config]}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)

  And now you have a working MessageBroker Consumer.

  ## Creating a Publisher

  To create a publisher, you'll need to create a module like this:

      defmodule MyPublisher do
        use MessageBroker, as: :publisher
      end

  Then add your module in a Supervisor (e.g. in your Application Supervisor) and configure it:

      config = %{
        repo: MyApp.Repo,
        rabbitmq_user: "guest",
        rabbitmq_password: "guest",
        rabbitmq_host: "localhost",
        rabbitmq_exchange: "example_exchange"
      }

      children = [
        {MyPublisher, [config: config]}
      ]

      Supervisor.start_link(children, strategy: :one_for_one)
  """

  defmacro __using__(as: consumer_or_publisher)
           when consumer_or_publisher in [:consumer, :publisher] do
    %Macro.Env{module: name} = __CALLER__
    name = String.replace(to_string(name), ".", "")

    case consumer_or_publisher do
      :consumer -> consumer_quote(name)
      :publisher -> publisher_quote(name)
    end
  end

  defp consumer_quote(name) do
    quote do
      use Supervisor

      alias MessageBroker.Consumer
      alias MessageBroker.Consumer.MessageRetrier

      def start_link(opts \\ []) do
        config = Keyword.fetch!(opts, :config)
        Supervisor.start_link(__MODULE__, config, name: __MODULE__)
      end

      @impl true
      def init(config) do
        Supervisor.init(children(config), strategy: :rest_for_one)
      end

      defp consumer_name,
        do: String.to_atom("Elixir.MessageBroker.Internal.#{unquote(name)}Consumer")

      defp message_retrier_name,
        do: String.to_atom("Elixir.MessageBroker.Internal.#{unquote(name)}MessageRetrier")

      defp children(config) do
        config =
          config
          |> Map.put(:consumer_name, consumer_name())
          |> Map.put(:message_retrier_name, message_retrier_name())

        consumer_config = struct(MessageBroker.ConsumerConfig, config)

        [{MessageRetrier, consumer_config}, {Consumer, consumer_config}]
      end

      defdelegate handle_message(_any, message, context), to: Consumer
    end
  end

  defp publisher_quote(name) do
    quote do
      use Supervisor

      alias MessageBroker.Publisher
      alias MessageBroker.Publisher.Notifier

      def start_link(opts \\ []) do
        config = Keyword.fetch!(opts, :config)
        Supervisor.start_link(__MODULE__, config, name: __MODULE__)
      end

      @impl true
      def init(config) do
        Supervisor.init(children(config), strategy: :one_for_one)
      end

      defp children(config) do
        config =
          config
          |> Map.put(:publisher_name, publisher_name())
          |> Map.put(:notifier_name, notifier_name())

        publisher_config = struct(MessageBroker.PublisherConfig, config)

        [{Publisher, publisher_config}, {Notifier, publisher_config}]
      end

      defp publisher_name,
        do: String.to_atom("Elixir.MessageBroker.Internal.#{unquote(name)}Publisher")

      defp notifier_name,
        do: String.to_atom("Elixir.MessageBroker.Internal.#{unquote(name)}Notifier")

      def publish_event(event), do: Publisher.publish_event(publisher_name(), event)

      defdelegate build_event_payload(event), to: Publisher
    end
  end
end

defmodule MessageBroker.ConsumerConfig do
  @moduledoc false

  @type t :: %__MODULE__{
          consumer_name: atom(),
          message_retrier_name: atom(),
          rabbitmq_user: String.t(),
          rabbitmq_password: String.t(),
          rabbitmq_host: String.t(),
          rabbitmq_exchange: String.t(),
          rabbitmq_queue: String.t(),
          rabbitmq_subscribed_topics: list(),
          rabbitmq_message_handler: function(),
          rabbitmq_broadway_options: keyword(),
          rabbitmq_retries_count: integer()
        }

  defstruct [
    :consumer_name,
    :message_retrier_name,
    rabbitmq_user: "guest",
    rabbitmq_password: "guest",
    rabbitmq_host: "localhost",
    rabbitmq_exchange: "example_exchange",
    rabbitmq_queue: "example_queue",
    rabbitmq_subscribed_topics: [],
    rabbitmq_message_handler: &MessageBroker.MessageHandler.handle_message/2,
    rabbitmq_broadway_options: [],
    rabbitmq_retries_count: 3
  ]
end

defmodule MessageBroker.PublisherConfig do
  @moduledoc false

  @type t :: %__MODULE__{
          publisher_name: atom(),
          notifier_name: atom(),
          repo: Ecto.Repo.t(),
          rabbitmq_user: String.t(),
          rabbitmq_password: String.t(),
          rabbitmq_host: String.t(),
          rabbitmq_exchange: String.t()
        }

  defstruct [
    :publisher_name,
    :notifier_name,
    :repo,
    rabbitmq_user: "guest",
    rabbitmq_password: "guest",
    rabbitmq_host: "localhost",
    rabbitmq_exchange: "example_exchange"
  ]
end
