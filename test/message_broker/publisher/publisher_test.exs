defmodule MessageBroker.PublisherTest do
  use MessageBroker.DataCase

  import MessageBroker.ApplicationTestHelper

  alias MessageBroker.Publisher.Event

  describe "#publish_event/1" do
    test "sucessful publish an event" do
      {:ok, pid} = start_publisher(MyPublisher)

      event = %Event{event_name: "my_event", payload: %{id: "123"}}
      assert {:ok, :ok} = MyPublisher.publish_event(event)

      kill_application(pid)
    end
  end

  describe "#build_event_payload/1" do
    test "pass an event struct and convert it to a valid json" do
      {:ok, pid} = start_publisher(MyPublisher)

      event = %Event{event_name: "my_event", payload: %{id: "123"}}
      payload = MyPublisher.build_event_payload(event)

      assert is_bitstring(payload)

      assert %{
               "event" => "my_event",
               "timestamp" => timestamp,
               "payload" => %{"id" => "123"}
             } = Jason.decode!(payload)

      assert {:ok, _, _} = DateTime.from_iso8601(timestamp)

      kill_application(pid)
    end
  end
end
