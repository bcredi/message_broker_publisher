defmodule MessageBroker.MessageHandlerMock do
  @moduledoc """
  Mock for Consumer test.
  """

  @callback handle_message(map(), map()) :: :ok | any()
end
