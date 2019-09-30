defmodule MessageBroker.Consumer.MessageRetrierTest do
  use ExUnit.Case

  import MessageBroker.ApplicationTestHelper

  alias MessageBroker.Consumer.MessageRetrier

  describe "#retry_message/3" do
    setup do
      config =
        Map.merge(consumer_default_config(), %{
          message_retrier_name: MyRetrier,
          rabbitmq_retries_count: 2
        })

      {:ok, pid} = MessageRetrier.start_link(config)

      {:ok, %{pid: pid}}
    end

    test "sucessfully retries an event", %{pid: pid} do
      message = "{\"test\": \"#{Faker.Lorem.paragraph(3)}\"}"

      headers = [{"x-death", :array, [table: [{"count", :long, 0}]]}]

      assert {:ok, :message_retried} = MessageRetrier.retry_message(MyRetrier, message, headers)

      Process.exit(pid, :normal)

      # Wait retry time (1s) and consume message to clean the queue
      Process.sleep(2_000)
      {:ok, chan} = open_rabbitmq_connection()
      {:ok, _p, _m} = get_rabbitmq_message(chan, default_queue())
    end

    test "reject an event that expired its retries", %{pid: pid} do
      message = "{\"test\": \"#{Faker.Lorem.paragraph(3)}\"}"

      headers = [
        {"x-death", :array, [table: [{"count", :long, 1}], table: [{"count", :long, 1}]]}
      ]

      assert {:error, :message_retries_expired} =
               MessageRetrier.retry_message(MyRetrier, message, headers)

      Process.exit(pid, :normal)
    end
  end
end
