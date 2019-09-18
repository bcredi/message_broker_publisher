defmodule MessageBroker.Event do
  @moduledoc """
  The ...
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "message_broker_events" do
    field(:event_name, :string)
    field(:payload, :map)

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_name, :payload])
    |> validate_required([:event_name, :payload])
  end
end
