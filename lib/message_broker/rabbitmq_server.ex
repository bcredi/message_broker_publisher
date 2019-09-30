defmodule MessageBroker.RabbitmqServer do
  @moduledoc """
  Generic RabbitMQ GenServer to handle its connection.
  """

  defmacro __using__(as: server_name) when is_bitstring(server_name) do
    quote do
      use AMQP
      use GenServer

      alias AMQP.{Channel, Connection}

      require Logger

      def start_link(opts \\ []) do
        GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      end

      defp rabbitmq_connect do
        Logger.info("Connecting to RabbitMQ (#{unquote(server_name)}).")

        case open_connection() do
          {:ok, conn} ->
            # Get notifications when the connection goes down
            Process.monitor(conn.pid)
            {:ok, chan} = Channel.open(conn)
            {:ok, chan}

          {:error, error} ->
            # Reconnection loop
            Logger.info(
              "Reconnecting to RabbitMQ (#{unquote(server_name)}).\nReason: #{inspect(error)}"
            )

            Process.sleep(10_000)
            rabbitmq_connect()
        end
      end

      defp open_connection do
        Connection.open(
          username: MessageBroker.get_config(:rabbitmq_user),
          password: MessageBroker.get_config(:rabbitmq_password),
          host: MessageBroker.get_config(:rabbitmq_host),
          virtual_host: "/"
        )
      end

      @impl GenServer
      def handle_info({:EXIT, _pid, :shutdown}, _state) do
        File.touch("rabbit_error")

        Logger.info(
          "RabbitMQ (#{unquote(server_name)}) connection has died (:EXIT), therefore I have to die as well."
        )

        Process.exit(self(), :kill)
      end

      @impl GenServer
      def handle_info({:DOWN, _, :process, _pid, reason}, _state) do
        File.touch("rabbit_error")

        Logger.error("""
        RabbitMQ (#{unquote(server_name)}) connection has died (:DOWN), therefore I have to die as well.\n
        Reason: #{inspect(reason)}
        """)

        Process.exit(self(), :kill)
      end
    end
  end
end
