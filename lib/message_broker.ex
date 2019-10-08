defmodule MessageBroker do
  @moduledoc """
  MessageBroker aims to consume and publish events.
  """

  defmacro __using__(as: consumer_or_publisher, name: name)
           when consumer_or_publisher in [:consumer, :publisher] and is_binary(name) do
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
        do: String.to_atom("Elixir.MessageBrokerInternal.#{unquote(name)}Consumer")

      defp message_retrier_name,
        do: String.to_atom("Elixir.MessageBrokerInternal.#{unquote(name)}MessageRetrier")

      defp children(config) do
        config =
          config
          |> Map.put(:consumer_name, consumer_name())
          |> Map.put(:message_retrier_name, message_retrier_name())

        consumer_config = struct(MessageBroker.ConsumerConfig, config)

        [{MessageRetrier, consumer_config}, {Consumer, consumer_config}]
      end

      defdelegate handle_message(_any, message, context),
        to: String.to_atom("Elixir.MessageBrokerInternal.#{unquote(name)}Consumer")
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
        do: String.to_atom("Elixir.MessageBrokerInternal.#{unquote(name)}Publisher")

      defp notifier_name,
        do: String.to_atom("Elixir.MessageBrokerInternal.#{unquote(name)}Notifier")

      def publish_event(event) do
        publisher_name().publish_event(publisher_name(), event)
      end

      defdelegate build_event_payload(event),
        to: String.to_atom("Elixir.MessageBrokerInternal.#{unquote(name)}Publisher")
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
          repo: Ecto.Repo.t(),
          publisher_name: atom(),
          notifier_name: atom(),
          rabbitmq_user: String.t(),
          rabbitmq_password: String.t(),
          rabbitmq_host: String.t(),
          rabbitmq_exchange: String.t()
        }

  defstruct [
    :repo,
    :publisher_name,
    :notifier_name,
    rabbitmq_user: "guest",
    rabbitmq_password: "guest",
    rabbitmq_host: "localhost",
    rabbitmq_exchange: "example_exchange"
  ]
end
