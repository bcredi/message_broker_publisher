defmodule MessageBroker.Consumer do
  @moduledoc """
  RabbitMQ Consumer.

  This is a Broadway application that keeps a connection open with the broker and
  know how to consume messages from it.
  """

  use Broadway

  alias Broadway.Message
  alias MessageBroker.Consumer.{MessageRetrier, Setup}

  def start_link(config) do
    Setup.init(config)
    Broadway.start_link(__MODULE__, broadway_options(config))
  end

  defp broadway_options(%{
         rabbitmq_user: user,
         rabbitmq_password: password,
         rabbitmq_host: host,
         rabbitmq_queue: queue,
         rabbitmq_message_handler: message_handler,
         rabbitmq_broadway_options: custom_options
       }) do
    default = [
      name: MessageBrokerConsumer,
      context: %{message_handler: message_handler},
      producers: [
        default: [
          module:
            {BroadwayRabbitMQ.Producer,
             queue: queue,
             connection: [
               username: user,
               password: password,
               host: host
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

    Keyword.merge(default, custom_options)
  end

  @impl true
  def handle_message(
        _,
        %Message{data: data, metadata: %{headers: headers} = metadata} = message,
        %{message_handler: message_handler}
      )
      when is_function(message_handler) do
    decoded_data = Jason.decode!(data)

    case message_handler.(decoded_data, metadata) do
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
end
