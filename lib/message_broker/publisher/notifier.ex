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

  def start_link(%{notifier_name: name, publisher_name: _, repo: _} = config) do
    GenServer.start_link(__MODULE__, config, name: name)
  end

  @spec listen(Struct.t(), String.t()) :: {:error, any} | {:ok, pid, reference}
  def listen(repo, event_name) do
    with {:ok, pid} <- Notifications.start_link(repo.config()),
         {:ok, ref} <- Notifications.listen(pid, event_name) do
      {:ok, pid, ref}
    end
  end

  @impl GenServer
  def init(%{repo: repo} = config) do
    case listen(repo, @channel) do
      {:ok, _pid, _ref} -> {:ok, config}
      error -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_info({:notification, _pid, _ref, @channel, payload}, %{
        publisher_name: publisher_name,
        repo: repo
      }) do
    with {:ok, %{"record" => %{"id" => id}}} <- Jason.decode(payload),
         event <- get_event!(repo, id) do
      Logger.info("Processing message broker event: #{inspect(event)}")

      Multi.new()
      |> Multi.delete(:delete_event, event)
      |> Multi.run(:publish_message, fn _, _ ->
        Publisher.publish_event(publisher_name, event)
      end)
      |> repo.transaction()
      |> case do
        {:ok, _changes} ->
          {:noreply, :event_handled}

        {:error, _, _, _} ->
          mark_as_error!(repo, event)
          {:noreply, :event_not_handled}
      end
    else
      error -> {:stop, error, []}
    end
  end

  def handle_info(_, _) do
    {:noreply, :event_received}
  end

  defp get_event!(repo, id), do: repo.get!(Event, id)
  defp mark_as_error!(repo, event), do: repo.update!(event, status: "error")
end
