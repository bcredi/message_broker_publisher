defmodule MessageBroker.Repo do
  use Ecto.Repo,
    otp_app: :message_broker,
    adapter: Ecto.Adapters.Postgres
end
