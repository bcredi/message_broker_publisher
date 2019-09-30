defmodule MessageBroker do
  @moduledoc """
  MessageBroker aims to consume and publish events.
  """

  use Supervisor

  alias MessageBroker.{Consumer, Notifier, Publisher}
  alias MessageBroker.Consumer.MessageRetrier
  alias MessageBroker.Publisher.Notifier

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = consumer_applications() ++ publisher_applications()

    Supervisor.init(children, strategy: :one_for_one)
  end

  defp consumer_applications do
    if get_config(:rabbitmq_consumer_enabled), do: [MessageRetrier, Consumer], else: []
  end

  defp publisher_applications do
    if get_config(:rabbitmq_publisher_enabled), do: [Publisher, Notifier], else: []
  end

  @doc """
  Returns a `%MessageBroker.Config{}` struct.

  ## Examples

  In your `config.exs`:

      config :message_broker,
        repo: MyApp.Repo,
        rabbitmq_consumer_enabled: true,
        rabbitmq_publisher_enabled: true,
        rabbitmq_user: "user",
        rabbitmq_password: "password",
        rabbitmq_host: "localhost",
        rabbitmq_exchange: "some_exchange",
        rabbitmq_consumer_queue: "some_queue",
        rabbitmq_consumer_subscribed_topics: ["some_app.some_schema.some_action"],
        rabbitmq_consumer_message_handler: &MyApp.MessageHandler.handle_message/2,
        rabbitmq_consumer_broadway_options: [processors: [default: [stages: 5]]],
        rabbitmq_consumer_retries_count: 3

      iex> config()
      %MessageBroker.Config{}

  """
  @spec config :: MessageBroker.Config.t()
  def config, do: struct(MessageBroker.Config, Application.get_all_env(:message_broker))

  @doc """
  Returns a specific *key* for the config.
  If the *key* doesn't exists, returns nil.

  ## Examples

      iex> get_config(:repo)
      MyApp.Repo

      iex> get_config(:invalid_key)
      nil

  """
  @spec get_config(atom()) :: any
  def get_config(key), do: Map.get(config(), key)

  defmodule Config do
    @moduledoc false

    @type t :: %__MODULE__{
            rabbitmq_consumer_enabled: boolean(),
            rabbitmq_publisher_enabled: boolean(),
            repo: Ecto.Repo.t(),
            rabbitmq_user: String.t(),
            rabbitmq_password: String.t(),
            rabbitmq_host: String.t(),
            rabbitmq_exchange: String.t(),
            rabbitmq_consumer_queue: String.t(),
            rabbitmq_consumer_subscribed_topics: list(),
            rabbitmq_consumer_message_handler: function(),
            rabbitmq_consumer_broadway_options: keyword(),
            rabbitmq_consumer_retries_count: integer()
          }

    defstruct [
      :repo,
      rabbitmq_consumer_enabled: false,
      rabbitmq_publisher_enabled: false,
      rabbitmq_user: "guest",
      rabbitmq_password: "guest",
      rabbitmq_host: "localhost",
      rabbitmq_exchange: "example_exchange",
      rabbitmq_consumer_queue: "example_queue",
      rabbitmq_consumer_subscribed_topics: [],
      rabbitmq_consumer_message_handler: &MessageBroker.MessageHandler.handle_message/2,
      rabbitmq_consumer_broadway_options: [],
      rabbitmq_consumer_retries_count: 3
    ]
  end
end
