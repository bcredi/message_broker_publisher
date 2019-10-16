defmodule MessageBroker.Consumer.MessageRetrierHelperTest do
  use ExUnit.Case

  alias MessageBroker.Consumer.MessageRetrierHelper, as: Helper

  describe "#death_count/1" do
    defp death_count_headers(count)
    defp death_count_headers(0), do: [{"x-death", :long, []}]

    defp death_count_headers(count) when count > 0 do
      count_values =
        Enum.reduce(0..(count - 1), [], fn _, acc ->
          acc ++ [{:table, [{"count", :long, 1}, {"some_value", :long, Enum.random(1..1000)}]}]
        end)

      [{"x-death", :long, count_values}]
    end

    test "for undefined headers returns 0" do
      assert 0 == Helper.death_count(:undefined)
    end

    test "for headers with 0 counts" do
      headers = death_count_headers(0)

      assert 0 == Helper.death_count(headers)
    end

    test "for headers with 1 count" do
      headers = death_count_headers(1)

      assert 1 == Helper.death_count(headers)
    end

    test "for headers with more than 1 count" do
      count = Enum.random(2..1000)
      headers = death_count_headers(count)

      assert count == Helper.death_count(headers)
    end
  end

  describe "#exponential_delay_milliseconds/1" do
    test "for retries below 0" do
      assert 0 == Helper.exponential_delay_milliseconds(Enum.random(-1..-1000))
    end

    test "for retries above -1" do
      assert 1_000 == Helper.exponential_delay_milliseconds(0)
      assert 9_000 == Helper.exponential_delay_milliseconds(2)
      assert 10_000_000 == Helper.exponential_delay_milliseconds(99)
    end
  end

  describe "#routing_key/2" do
    test "properly returns the queue" do
      assert "my_app.my_queue.1000" == Helper.routing_key("my_app.my_queue", 1000)
    end
  end
end
