defmodule MessageBroker do
  @moduledoc """
  MessageBroker aims to publish events
  """

  use Supervisor

  alias MessageBroker.Publisher
  alias MessageBroker.Notifier

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Publisher,
      Notifier
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  @doc """
  Returns a `%MessageBroker.Config{}` struct.

  ## Examples

  In your `config.exs`:

      config :message_broker,
        repo: MyApp.Repo,
        rabbitmq_user: "user",
        rabbitmq_password: "password",
        rabbitmq_host: "localhost",
        rabbitmq_exchange: "some_exchange",
        rabbitmq_topics: ["topic1", "topic2"]

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
            repo: Ecto.Repo.t(),
            rabbitmq_user: String.t(),
            rabbitmq_password: String.t(),
            rabbitmq_host: String.t(),
            rabbitmq_exchange: String.t(),
            rabbitmq_topics: list(String.t())
          }

    defstruct [
      :repo,
      :rabbitmq_user,
      :rabbitmq_password,
      :rabbitmq_host,
      :rabbitmq_exchange,
      :rabbitmq_topics
    ]
  end
end
