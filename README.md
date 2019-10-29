# MessageBroker

MessageBroker library handles event publication and consuming in Bcredi's Elixir applications.

For event publishing (Publisher), it gets persisted events in database, publish them, then deletes the row.

For event consuming (Consumer), it receives events from RabbitMQ, try to consume with an user-defined function,
and retries with exponential time if the event wasn't consumed.

## Requirements

MessageBroker has been developed and actively tested with Elixir 1.9+, Erlang/OTP 22+
and PostgreSQL 11.0+.
Running MessageBroker currently requires Elixir 1.8+, Erlang 21.1+, and PostgreSQL 9.6+.

## Installation

MessageBroker can be installed by adding `message_broker` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:message_broker, git: "https://github.com/bcredi/message_broker.git", tag: "v0.1.3"}
  ]
end
```

Then run `mix deps.get` to install MessageBroker and its dependencies.

If you want to use the Publisher, after the packages are installed you must create a database migration
to add the `message_broker_events` table to your database:

```bash
mix ecto.gen.migration add_message_broker_events_table
```

Open the generated migration in your editor and call the `up` and `down`
functions on `MessageBroker.Migrations`:

```elixir
defmodule MyApp.Repo.Migrations.AddMessageBrokerEventsTable do
  use Ecto.Migration

  alias MessageBroker.Publisher.Migrations

  def up, do: Migrations.up()

  def down, do: Migrations.down()
end
```

Now, run the migration to create the table:

```bash
mix ecto.migrate
```

Next see [Usage](#Usage) for how to integrate MessageBroker into your application and
start defining jobs!

## Usage

MessageBroker isn't an application and won't be started automatically. It is started by a
supervisor that must be included in your application's supervision tree. Consumer and Publisher
have a supervisor each and your configuration is passed into the `MessageBroker` supervisor `start_link` call.

### Consumer Usage

Consumer binds itself to an queue that receive topics from an exchange that you define.
To use Consumer, you must define a module that uses MessageBroker as consumer.

```elixir
defmodule MyApp.MyConsumer do
  use MessageBroker, as: :consumer
end
```

Then you must define a function that receives the events consumed.
If the event is successfully consumed you must return `:ok` or `{:ok, any()}`, anything else is an error.

```elixir
defmodule MyApp.MessageHandler do
  @moduledoc """
  Consumer MessageHandler.
  """

  @callback handle_message(map(), map()) :: :ok | {:ok, any()} | any()
  def handle_message(%{"event" => name, "payload" => payload} = event, _metadata) do
    case name do
      "some_app.some_schema.action" ->
        # do some processing with payload
        :ok
    end
  end
end
```

Then add consumer module in your Application supervisor and configure it.

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  @moduledoc false

  use Application

  alias MyApp.MyConsumer

  def start(_type, _args) do
    my_consumer_config = %{
      rabbitmq_user: "guest",
      rabbitmq_password: "guest",
      rabbitmq_host: "localhost",
      rabbitmq_exchange: "my_exchange",
      rabbitmq_queue: "my_queue",
      rabbitmq_subscribed_topics: ["some_app.some_schema.action"],
      rabbitmq_message_handler: &MyApp.MessageHandler.handle_message/2,
      rabbitmq_broadway_options: [],
      rabbitmq_retries_count: 3
    }

    children = [
      {MyConsumer, config: my_consumer_config}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

### Publisher Usage

Publisher binds itself to an exchange that you define and then it listen to events persisted in your database.
To use Publisher, you must define a module that uses MessageBroker as publisher.

```elixir
defmodule MyApp.MyPublisher do
  use MessageBroker, as: :publisher
end
```

Then add publisher module in your Application supervisor and configure it.
Your Repo must initialize before Publisher, because Publisher will publish all available
events when it starts.

```elixir
# lib/my_app/application.ex
defmodule MyApp.Application do
  @moduledoc false

  use Application

  alias MyApp.{MyPublisher, Repo}

  def start(_type, _args) do
    my_publisher_config = %{
      repo: Repo,
      rabbitmq_user: "guest",
      rabbitmq_password: "guest",
      rabbitmq_host: "localhost",
      rabbitmq_exchange: "my_exchange"
    }

    children = [
      Repo,
      {MyPublisher, config: my_publisher_config}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

To publish an event, you must define an event builder.

```elixir
defmodule MyApp.Events.MySchemaUpdatedEvent do
  @moduledoc false

  use MessageBroker.Publisher.EventBuilder, as: "my_app.my_schema.updated"

  @derive Jason.Encoder
  defstruct ~w(id inserted_at updated_at name)a

  # Is possible to process the schema before publishing it by defining `#process_payload/1`
  # or else it will just map the fields defined in `defstruct`.
  defp process_payload(%_{} = my_schema) do
    my_schema
    |> Map.from_struct()
    |> Map.put(:name, "Mr. #{my_schema.name}")
  end
end
```

Then insert events in database.

```elixir
alias MyApp.Events.MySchemaUpdatedEvent
alias MyApp.Repo

{:ok, _} =
  my_schema
  |> MySchemaUpdatedEvent.new()
  |> Repo.insert()
```

## Testing

When developing MessageBroker library, run tests with:

```
$ docker-compose run --rm test
```
