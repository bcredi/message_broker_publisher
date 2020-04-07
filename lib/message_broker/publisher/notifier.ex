defmodule MessageBroker.Publisher.Notifier do
  @moduledoc """
  Event Notifier.

  This is a GenServer that listen to Postgres Notifications and call the `Publisher`.
  Every `%Event{}` persisted to the database will be published by this process.

  """

  use GenServer

  import Ecto.Query

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
      {:ok, _pid, _ref} ->
        {:ok, config, {:continue, :process_available_events}}

      error ->
        {:stop, error}
    end
  end

  @impl GenServer
  def handle_continue(:process_available_events, %{publisher_name: _, repo: repo} = state) do
    Event
    |> where([e], is_nil(e.status))
    |> repo.all()
    |> Enum.each(&process_event(&1.id, state))

    {:noreply, state}
  end

  @impl GenServer
  def handle_info(
        {:notification, _pid, _ref, @channel, payload},
        %{publisher_name: _, repo: _} = state
      ) do
    case Jason.decode(payload) do
      {:ok, %{"record" => %{"id" => id}}} ->
        process_event(id, state)

      error ->
        {:stop, error, []}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp process_event(id, %{publisher_name: publisher_name, repo: repo} = state) do
    Multi.new()
    |> Multi.run(:event, fn _, _ -> get_event(repo, id) end)
    |> Multi.delete(:delete_event, fn %{event: event} -> event end)
    |> Multi.run(:publish_message, fn _, %{event: event} ->
      Logger.debug("Processing message broker event: #{inspect(event)}")
      Publisher.publish_event(publisher_name, event)
    end)
    |> repo.transaction()
    |> process_event_result(id, state)
  end

  defp get_event(repo, id) do
    case do_get_event(repo, id) do
      nil -> {:error, :event_not_found}
      :lock_not_available -> {:error, :event_locked}
      %Event{} = event -> {:ok, event}
      error -> {:error, error}
    end
  end

  defp do_get_event(repo, id) do
    Event
    |> where([e], e.id == ^id)
    |> lock("FOR UPDATE NOWAIT")
    |> repo.one()
  rescue
    e in Postgrex.Error ->
      %{postgres: %{code: error_code}} = e
      error_code
  end

  defp process_event_result(result, id, %{repo: repo} = state) do
    case result do
      {:ok, _changes} ->
        {:noreply, state}

      {:error, :event, :event_not_found, _} ->
        Logger.debug("Event ##{id} not found.")
        {:noreply, state}

      {:error, :event, :event_locked, _} ->
        Logger.debug("Event ##{id} locked.")
        {:noreply, state}

      {:error, :event, sql_error, _} ->
        {:stop, "SQL Error: #{sql_error}", []}

      {:error, action, error, %{event: %Event{} = event}} ->
        mark_as_error!(repo, event, action, error)
        {:noreply, state}
    end
  end

  defp mark_as_error!(repo, %{status: status} = event, action, error) do
    {:ok, now} = DateTime.now("Etc/UTC")

    new_status =
      Map.put(status, to_string(now), %{
        "type" => "error",
        "action" => to_string(action),
        "message" => inspect(error, limit: :infinity)
      })

    event
    |> Ecto.Changeset.change(status: new_status)
    |> repo.update!()
  end
end
