# MessageBroker

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `message_broker` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:message_broker, "~> 0.1.0"}
  ]
end
```

## Requirements

Oban has been developed and actively tested with Elixir 1.8+, Erlang/OTP 21.1+
and PostgreSQL 11.0+. Running Oban currently requires Elixir 1.8+, Erlang 21+, and PostgreSQL
9.6+.

## Installation

Oban is published on [Hex](https://hex.pm/packages/oban). Add it to your list of
dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:oban, "~> 0.5"}
  ]
end
```

Then run `mix deps.get` to install Oban and its dependencies, including
[Ecto][ecto], [Jason][jason] and [Postgrex][postgrex].

After the packages are installed you must create a database migration to
add the `oban_jobs` table to your database:

```bash
mix ecto.gen.migration add_oban_jobs_table
```

Open the generated migration in your editor and call the `up` and `down`
functions on `Oban.Migrations`:

```elixir
defmodule MyApp.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def up do
    Oban.Migrations.up()
  end

  # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
  # necessary, regardless of which version we've migrated `up` to.
  def down do
    Oban.Migrations.down(version: 1)
  end
end
```

This will run all of Oban's versioned migrations for your database. Migrations
between versions are idempotent and will _never_ change after a release. As new
versions are released you may need to run additional migrations.

Now, run the migration to create the table:

```bash
mix ecto.migrate
```

Next see [Usage](#Usage) for how to integrate Oban into your application and
start defining jobs!

[ecto]: https://hex.pm/packages/ecto
[jason]: https://hex.pm/packages/jason
[postgrex]: https://hex.pm/packages/postgrex

#### Note About Releases

If you are using releases you may see Postgrex errors logged during your initial
deploy (or any deploy requiring an Oban migration). The errors are only
temporary. After the migration has completed each queue will start producing
jobs normally.

## Usage

Oban isn't an application and won't be started automatically. It is started by a
supervisor that must be included in your application's supervision tree. All of
your configuration is passed into the `Oban` supervisor, allowing you to
configure Oban like the rest of your application.

```elixir
# config/config.exs
config :my_app, Oban,
  repo: MyApp.Repo,
  prune: {:maxlen, 100_000},
  queues: [default: 10, events: 50, media: 20]

# lib/my_app/application.ex
defmodule MyApp.Application do
  @moduledoc false

  use Application

  alias MyApp.{Endpoint, Repo}

  def start(_type, _args) do
    children = [
      Repo,
      Endpoint,
      {Oban, Application.get_env(:my_app, Oban)}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
  end
end
```

If you are running tests (which you should be) you'll want to disable pruning
and job dispatching altogether when testing:

```elixir
# config/test.exs
config :my_app, Oban, queues: false, prune: :disabled
```

Without dispatch and pruning disabled Ecto will raise constant ownership errors
and you won't be able to run tests.

#### Configuring Queues

Queues are specified as a keyword list where the key is the name of the queue
and the value is the maximum number of concurrent jobs. The following
configuration would start four queues with concurrency ranging from 5 to 50:

```elixir
queues: [default: 10, mailers: 20, events: 50, media: 5]
```

There isn't a limit to the number of queues or how many jobs may execute
concurrently. Here are a few caveats and guidelines:

* Each queue will run as many jobs as possible concurrently, up to the
  configured limit. Make sure your system has enough resources (i.e. database
  connections) to handle the concurrent load.
* Only jobs in the configured queues will execute. Jobs in any other queue
  will stay in the database untouched.
* Be careful how many concurrent jobs make expensive system calls (i.e. FFMpeg,
  ImageMagick). The BEAM ensures that the system stays responsive under load,
  but those guarantees don't apply when using ports or shelling out commands.

#### Defining Workers

Worker modules do the work of processing a job. At a minimum they must define a
`perform/2` function, which is called with an `args` map and the job struct.

Define a worker to process jobs in the `events` queue:

```elixir
defmodule MyApp.Business do
  use Oban.Worker, queue: "events", max_attempts: 10

  @impl Oban.Worker
  def perform(%{"id" => id}, _job) do
    model = MyApp.Repo.get(MyApp.Business.Man, id)

    IO.inspect(model)
  end
end
```

The value returned from `perform/2` is ignored, unless it returns an `{:error,
reason}` tuple. With an error return or when perform has an uncaught exception
or throw then the error will be reported and the job will be retried (provided
there are attempts remaining).

The `Business` worker can also be configured to prevent duplicates for a period
of time through the `:unique` option. Here we'll configure it to be unique for
60 seconds:

```elixir
use Oban.Worker, queue: "events", max_attempts: 10, unique: [period: 60]
```

#### Enqueueing Jobs

Jobs are simply Ecto structs and are enqueued by inserting them into the
database. For convenience and consistency all workers provide a `new/2`
function that converts an args map into a job changeset suitable for insertion:

```elixir
%{in_the: "business", of_doing: "business"}
|> MyApp.Business.new()
|> Oban.insert()
```

The worker's defaults may be overridden by passing options:

```elixir
%{vote_for: "none of the above"}
|> MyApp.Business.new(queue: "special", max_attempts: 5)
|> Oban.insert()
```

Jobs may be scheduled at a specific datetime in the future:

```elixir
%{id: 1}
|> MyApp.Business.new(scheduled_at: ~U[2020-12-25 19:00:56.0Z])
|> Oban.insert()
```

Jobs may also be scheduled down to the second any time in the future:

```elixir
%{id: 1}
|> MyApp.Business.new(schedule_in: 5)
|> Oban.insert()
```

Unique jobs can be configured in the worker, or when the job is built:

```elixir
%{email: "brewster@example.com"}
|> MyApp.Mailer.new(unique: [period: 300, fields: [:queue, :worker])
|> Oban.insert()
```

Multiple jobs can be inserted in a single transaction:

```elixir
Ecto.Multi.new()
|> Oban.insert(:b_job, MyApp.Business.new(%{id: 1}))
|> Oban.insert(:m_job, MyApp.Mailer.new(%{email: "brewser@example.com"}))
|> Repo.transaction()
```

Occasionally you may need to insert a job for a worker that exists in another
application. In that case you can use `Oban.Job.new/2` to build the changeset
manually:

```elixir
%{id: 1, user_id: 2}
|> Oban.Job.new(queue: :default, worker: OtherApp.Worker)
|> Oban.insert()
```

`Oban.insert/2,4` is the preferred way of inserting jobs as it provides some of
Oban's advanced features (i.e., unique jobs). However, you can use your
application's `Repo.insert/2` function if necessary.

#### Pruning

Although Oban keeps all jobs in the database for durability and observability,
it's not a great thing if the table grows indefinitely. Job pruning helps us by
deleting old records from the `oban_jobs` tables. It has 3 modes:

* Disabled - No jobs are deleted. Example: `:disabled`
* Limit-based - Keeps the latest N records. Example: `{:maxlen, 100_000}`
* Time-based - Keeps records for the last N seconds. Example for 7 days: `{:maxage, 60 * 60 * 24 * 7}`

**Important**: Pruning is only applied to jobs that are completed or discarded
(has reached the maximum number of retries or has been manually killed). It'll
never delete a new job, a scheduled job or a job that failed and will be
retried.

## Testing

As noted in the Usage section above there are some guidelines for running tests:

* Disable all job dispatching by setting `queues: false` or `queues: nil` in your `test.exs`
  config. Keyword configuration is deep merged, so setting `queues: []` won't have any effect.

* Disable pruning via `prune: :disabled`. Pruning isn't necessary in testing mode because jobs
  created within the sandbox are rolled back at the end of the test. Additionally, the periodic
  pruning queries will raise `DBConnection.OwnershipError` when the application boots.

* Be sure to use the Ecto Sandbox for testing. Oban makes use of database pubsub
  events to dispatch jobs, but pubsub events never fire within a transaction.
  Since sandbox tests run within a transaction no events will fire and jobs
  won't be dispatched.

  ```elixir
  config :my_app, MyApp.Repo, pool: Ecto.Adapters.SQL.Sandbox
  ```

Oban provides some helpers to facilitate testing. The helpers handle the
boilerplate of making assertions on which jobs are enqueued. To use the
`assert_enqueued/1` and `refute_enqueued/1` helpers in your tests you must
include them in your testing module and specify your app's Ecto repo:

```elixir
use Oban.Testing, repo: MyApp.Repo
```

Now you can assert, refute or list jobs that have been enqueued within your
tests:

```elixir
assert_enqueued worker: MyWorker, args: %{id: 1}

# or

refute_enqueued queue: "special", args: %{id: 2}

# or

assert [%{args: %{"id" => 1}}] = all_enqueued worker: MyWorker
```

See the `Oban.Testing` module for more details.

### Integration Testing

During integration testing it may be necessary to run jobs because they do work
essential for the test to complete, i.e. sending an email, processing media,
etc. You can execute all available jobs in a particular queue by calling
`Oban.drain_queue/1` directly from your tests.

For example, to process all pending jobs in the "mailer" queue while testing
some business logic:

```elixir
defmodule MyApp.BusinessTest do
  use MyApp.DataCase, async: true

  alias MyApp.{Business, Worker}

  test "we stay in the business of doing business" do
    :ok = Business.schedule_a_meeting(%{email: "monty@brewster.com"})

    assert %{success: 1, failure: 0} == Oban.drain_queue(:mailer)

    # Now, make an assertion about the email delivery
  end
end
```

See `Oban.drain_queue/1` for additional details.