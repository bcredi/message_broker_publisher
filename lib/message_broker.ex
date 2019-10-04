defmodule MessageBroker do
  @moduledoc """
  MessageBroker aims to consume and publish events.
  """
  defmacro __using__(as: consumer_or_publisher)
           when consumer_or_publisher == :consumer or consumer_or_publisher == :publisher do
    quote do
      use Supervisor

      alias MessageBroker.{Consumer, Publisher}
      alias MessageBroker.Consumer.MessageRetrier
      alias MessageBroker.Publisher.Notifier

      def start_link(opts \\ []) do
        config = Keyword.fetch!(opts, :config)
        Supervisor.start_link(__MODULE__, config, name: __MODULE__)
      end

      @impl true
      def init(%{enabled: enabled} = config) when enabled == true do
        consumer_or_publisher = unquote(consumer_or_publisher)
        children = children(build_config(config), consumer_or_publisher)
        Supervisor.init(children, strategy: strategy(consumer_or_publisher))
      end

      def init(_config) do
        Supervisor.init([], strategy: :one_for_one)
      end

      defp children(config, :consumer), do: [{MessageRetrier, config}, {Consumer, config}]
      defp children(config, :publisher), do: [{Publisher, config}, {Notifier, config}]

      defp strategy(:consumer), do: :rest_for_one
      defp strategy(:publisher), do: :one_for_one

      defp build_config(config) do
        case unquote(consumer_or_publisher) do
          :consumer -> struct(MessageBroker.ConsumerConfig, config)
          :publisher -> struct(MessageBroker.PublisherConfig, config)
        end
      end
    end
  end
end

defmodule MessageBroker.ConsumerConfig do
  @moduledoc false

  @type t :: %__MODULE__{
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

  defstruct rabbitmq_user: "guest",
            rabbitmq_password: "guest",
            rabbitmq_host: "localhost",
            rabbitmq_exchange: "example_exchange",
            rabbitmq_queue: "example_queue",
            rabbitmq_subscribed_topics: [],
            rabbitmq_message_handler: &MessageBroker.MessageHandler.handle_message/2,
            rabbitmq_broadway_options: [],
            rabbitmq_retries_count: 3
end

defmodule MessageBroker.PublisherConfig do
  @moduledoc false

  @type t :: %__MODULE__{
          repo: Ecto.Repo.t(),
          rabbitmq_user: String.t(),
          rabbitmq_password: String.t(),
          rabbitmq_host: String.t(),
          rabbitmq_exchange: String.t()
        }

  defstruct [
    :repo,
    rabbitmq_user: "guest",
    rabbitmq_password: "guest",
    rabbitmq_host: "localhost",
    rabbitmq_exchange: "example_exchange"
  ]
end
