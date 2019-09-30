defmodule MessageBroker.Publisher.EventTest do
  use ExUnit.Case

  alias MessageBroker.Publisher.Event

  describe "#changeset/2" do
    test "require event_name and payload" do
      assert %Ecto.Changeset{
               errors: [
                 event_name: {"can't be blank", [validation: :required]},
                 payload: {"can't be blank", [validation: :required]}
               ]
             } = Event.changeset(%Event{}, %{})
    end
  end
end
