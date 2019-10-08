defmodule MessageBroker.Repo do
  @moduledoc """
  Used for tests.
  """

  use Ecto.Repo,
    otp_app: :message_broker,
    adapter: Ecto.Adapters.Postgres
end
