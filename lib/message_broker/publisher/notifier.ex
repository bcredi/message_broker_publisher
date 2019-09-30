defmodule MessageBroker.Publisher.Notifier do
  @moduledoc """
  Event Notifier.

  This is a GenServer that listen to Postgres Notifications and call the `Publisher`.
  Every `%Event{}` persisted to the database will be published by this process.

  """

  use GenServer

  alias Ecto.Multi
  alias Postgrex.Notifications

  alias MessageBroker.Publisher
  alias MessageBroker.Publisher.Event

  require Logger

  @channel "event_created"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec listen(String.t()) :: {:error, any} | {:ok, pid, reference}
  def listen(event_name) do
    with {:ok, pid} <- Notifications.start_link(repo().config()),
         {:ok, ref} <- Notifications.listen(pid, event_name) do
      {:ok, pid, ref}
    end
  end

  @impl GenServer
  def init(opts) do
    case listen(@channel) do
      {:ok, _pid, _ref} -> {:ok, opts}
      error -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_info({:notification, _pid, _ref, @channel, payload}, _) do
    with {:ok, %{"record" => %{"id" => id}}} <- Jason.decode(payload),
         event <- get_event!(id) do
      Logger.info("Processing message broker event: #{inspect(event)}")

      Multi.new()
      |> Multi.delete(:delete_event, event)
      |> Multi.run(:publish_message, fn _, _ -> Publisher.publish_event(event) end)
      |> repo().transaction()
      |> case do
        {:ok, _changes} ->
          {:noreply, :event_handled}

        {:error, _, _, _} ->
          mark_as_error!(event)
          {:noreply, :event_not_handled}
      end
    else
      error -> {:stop, error, []}
    end
  end

  def handle_info(_, _) do
    {:noreply, :event_received}
  end

  defp get_event!(id), do: repo().get!(Event, id)
  defp mark_as_error!(event), do: repo().update!(event, status: "error")
  defp repo, do: MessageBroker.get_config(:repo)
end
