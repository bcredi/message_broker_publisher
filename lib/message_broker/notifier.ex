defmodule MessageBroker.Notifier do
  use GenServer

  alias Ecto.Multi
  alias Postgrex.Notifications

  alias MessageBroker.Event

  require Logger

  @channel "event_created"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def listen(event_name) do
    with {:ok, pid} <- Notifications.start_link(repo()),
         {:ok, ref} <- Notifications.listen(pid, event_name) do
      {:ok, pid, ref}
    end
  end

  @impl GenServer
  def init(opts) do
    with {:ok, _pid, _ref} <- listen(@channel) do
      {:ok, opts}
    else
      error -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_info({:notification, _pid, _ref, @channel, payload}, _) do
    with {:ok, %{"record" => %{"id" => id}}} <- Jason.decode(payload),
         event <- get_event!(id) do
      Logger.info("Processing message broker event: #{inspect(event)}")

      {:ok, _changes} =
        Multi.new()
        |> Multi.delete(:delete_event, event)
        |> Multi.run(:publish_message, fn _, _ -> publish_event(event) end)
        |> repo().transaction()

      {:noreply, :event_handled}
    else
      error -> {:stop, error, []}
    end
  end

  def handle_info(_, _) do
    {:noreply, :event_received}
  end

  defp publish_event(%Event{event_name: event_name, payload: payload}) do
    event = %{
      event_name: event_name,
      timestamp: get_timestamp(),
      payload: Jason.encode!(payload)
    }

    {:ok, event}
  end

  defp get_timestamp do
    {:ok, dt} = DateTime.now("Etc/UTC")
    DateTime.to_iso8601(dt, :extended)
  end

  defp get_event!(id), do: repo().get!(Event, id)

  defp repo, do: MessageBroker.config().repo
end
