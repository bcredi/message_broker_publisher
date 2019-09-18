defmodule MessageBroker.Notifier do
  use GenServer

  alias Ecto.Multi
  alias Postgrex.Notifications

  alias MessageBroker.Event

  require Logger

  @channel "event_created"

  def start_link(configs) do
    GenServer.start_link(__MODULE__, configs, name: __MODULE__)
  end

  def listen(event_name, repo) do
    with {:ok, pid} <- Notifications.start_link(repo.config()),
         {:ok, ref} <- Notifications.listen(pid, event_name) do
      {:ok, pid, ref}
    end
  end

  @impl GenServer
  def init(configs) do
    with {:ok, _pid, _ref} <- listen(@channel, configs.repo) do
      {:ok, configs}
    else
      error -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_info({:notification, _pid, _ref, @channel, payload}, config) do
    with {:ok, %{"record" => %{"id" => id}}} <- Jason.decode(payload),
         event <- get_event!(id, config.repo) do
      Logger.info("Processing message broker event: #{inspect(event)}")

      {:ok, _changes} =
        Multi.new()
        |> Multi.delete(:delete_event, event)
        |> Multi.run(:publish_message, fn _repo, _changes ->
          publish_event(event)
        end)
        |> config.repo.transaction()

      {:noreply, :event_handled}
    else
      error -> {:stop, error, []}
    end
  end

  def handle_info(_, _state), do: {:noreply, :event_received}

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

  defp get_event!(id, repo), do: repo.get!(Event, id)
end
