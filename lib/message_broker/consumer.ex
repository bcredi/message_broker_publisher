defmodule MessageBroker.Consumer do
  @moduledoc """
  RabbitMQ Consumer.

  This is a Broadway application that keeps a connection open with the broker and
  know how to consume messages from it.
  """

  use Broadway

  alias Broadway.Message
  alias MessageBroker.Consumer.{MessageRetrier, Setup}

  def start_link(_opts) do
    Setup.init()
    Broadway.start_link(__MODULE__, broadway_options())
  end

  defp broadway_options do
    default = [
      name: MessageBrokerConsumer,
      producers: [
        default: [
          module:
            {BroadwayRabbitMQ.Producer,
             queue: MessageBroker.get_config(:rabbitmq_consumer_queue),
             connection: [
               username: MessageBroker.get_config(:rabbitmq_user),
               password: MessageBroker.get_config(:rabbitmq_password),
               host: MessageBroker.get_config(:rabbitmq_host)
             ],
             requeue: :never,
             metadata: [:headers]}
        ]
      ],
      processors: [
        default: [
          stages: 10
        ]
      ]
    ]

    Keyword.merge(default, MessageBroker.get_config(:rabbitmq_consumer_broadway_options))
  end

  @impl true
  def handle_message(
        _,
        %Message{data: data, metadata: %{headers: headers} = metadata} = message,
        _
      ) do
    decoded_data = Jason.decode!(data)

    case message_handler().(decoded_data, metadata) do
      :ok -> message
      error -> handle_failed_message(message, error, data, headers)
    end
  end

  defp handle_failed_message(message, error, data, headers) do
    case MessageRetrier.retry_message(data, headers) do
      {:ok, :message_retried} -> message
      {:error, :message_retries_expired} -> Message.failed(message, error)
    end
  end

  defp message_handler, do: MessageBroker.get_config(:rabbitmq_consumer_message_handler)
end
