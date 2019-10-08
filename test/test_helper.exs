ExUnit.start()

{:ok, _pid} =
  Supervisor.start_link([MessageBroker.Repo],
    strategy: :one_for_one,
    name: MessageBroker.Test.Supervisor
  )

Ecto.Adapters.SQL.Sandbox.mode(MessageBroker.Repo, :manual)
