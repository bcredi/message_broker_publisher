defmodule MessageBroker.Repo.Migrations.AddMessageBrokerPublisher do
  use Ecto.Migration

  alias MessageBroker.Publisher.Migrations

  def up, do: Migrations.up()

  def down, do: Migrations.down()
end
