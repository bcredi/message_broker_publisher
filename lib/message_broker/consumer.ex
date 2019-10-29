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
         consumer_name: name,
         message_retrier_name: message_retrier_name,
         rabbitmq_user: user,
         rabbitmq_password: password,
         rabbitmq_host: host,
         rabbitmq_queue: queue,
         rabbitmq_message_handler: message_handler,
         rabbitmq_broadway_options: custom_options
       }) do
    default = [
      name: name,
      context: %{message_handler: message_handler, message_retrier_name: message_retrier_name},
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
        %Message{data: data, metadata: metadata} = message,
        %{message_handler: message_handler, message_retrier_name: message_retrier_name}
      )
      when is_function(message_handler) do
    headers = Map.get(metadata, :headers)

    case message_handler.(decode_data(data), metadata) do
      :ok -> message
      {:ok, _} -> message
      error -> handle_failed_message(message, error, data, headers, message_retrier_name)
    end
  end

  defp decode_data(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> decoded
      _ -> data
    end
  end

  defp handle_failed_message(message, error, data, headers, message_retrier_name) do
    case MessageRetrier.retry_message(message_retrier_name, data, headers) do
      {:ok, :message_retried} -> message
      {:error, :message_retries_expired} -> Message.failed(message, error)
    end
  end
end
