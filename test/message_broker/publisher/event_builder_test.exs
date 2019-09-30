defmodule MessageBroker.Publisher.EventBuilderTest do
  use ExUnit.Case

  defmodule MyEvent do
    use MessageBroker.Publisher.EventBuilder, as: "my_event"
    defstruct [:key1, :key2]
  end

  defmodule MyStruct do
    defstruct [:key1, :key2, :key3]
  end

  alias MessageBroker.Publisher.Event
  alias MessageBroker.Publisher.EventBuilderTest.MyEvent

  describe "#new/1" do
    test "returns Ecto.Changeset with map as argument" do
      assert %Ecto.Changeset{
               changes: %{
                 event_name: "my_event",
                 payload: %MyEvent{
                   key1: "1",
                   key2: "2"
                 }
               },
               errors: [],
               data: %Event{}
             } = MyEvent.new(%{key1: "1", key2: "2", key3: "3"})
    end

    test "returns Ecto.Changeset with struct as argument" do
      assert %Ecto.Changeset{
               changes: %{
                 event_name: "my_event",
                 payload: %MyEvent{
                   key1: "1",
                   key2: "2"
                 }
               },
               errors: [],
               data: %Event{}
             } = MyEvent.new(%MyStruct{key1: "1", key2: "2", key3: "3"})
    end
  end
end
