defmodule MessageBroker.PublisherTest do
  use ExUnit.Case

  alias MessageBroker.Publisher
  alias MessageBroker.Publisher.Event

  describe "#publish_event/1" do
    test "sucessful publish an event" do
      {:ok, _pid} = Publisher.start_link()
      event = %Event{event_name: "my_event", payload: %{id: "123"}}
      assert {:ok, :ok} = Publisher.publish_event(event)
    end
  end

  describe "#build_event_payload/1" do
    test "pass an event struct and convert it to a valid json" do
      event = %Event{event_name: "my_event", payload: %{id: "123"}}
      payload = Publisher.build_event_payload(event)

      assert is_bitstring(payload)

      assert %{
               "event" => "my_event",
               "timestamp" => timestamp,
               "payload" => %{"id" => "123"}
             } = Jason.decode!(payload)

      assert {:ok, _, _} = DateTime.from_iso8601(timestamp)
    end
  end
end
