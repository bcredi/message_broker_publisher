defmodule MessageBroker do
  @moduledoc """
  Documentation for MessageBroker.
  """

  def config, do: struct(MessageBroker.Config, Application.get_all_env(:message_broker))

  defmodule MessageBroker.Config do
    @moduledoc false

    defstruct [:repo]
  end
end
