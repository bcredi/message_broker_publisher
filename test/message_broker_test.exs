defmodule MessageBrokerTest do
  use ExUnit.Case

  describe "#config/0" do
    test "returns the MessageBroker.Config struct" do
      assert %MessageBroker.Config{} = MessageBroker.config()
    end
  end

  describe "#get_config/1" do
    @configs %{
      repo: MyApp.Repo,
      rabbitmq_user: "user",
      rabbitmq_password: "password",
      rabbitmq_host: "localhost",
      rabbitmq_exchange: "some_exchange"
    }

    test "returns the specified key of MessageBroker.Config struct" do
      for {key, value} <- @configs do
        :ok = Application.put_env(:message_broker, key, value)
        assert value == MessageBroker.get_config(key)
      end
    end

    test "returns nil if the key doesn't exists" do
      assert is_nil(MessageBroker.get_config(:invalid_key))
    end
  end
end
