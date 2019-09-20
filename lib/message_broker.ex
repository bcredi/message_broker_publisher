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

  @spec config :: MessageBroker.Config.t()
  def config, do: struct(MessageBroker.Config, Application.get_all_env(:message_broker))

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
