defmodule MessageBroker.Consumer.MessageRetrierHelper do
  @moduledoc """
  Helper functions for MessageRetrier.
  """

  @doc """
  Get death count from RabbitMQ message headers.

  ## Examples

    iex> death_count([{"x-death", :long, []}, ...])
    0

    iex> death_count([{"x-death", :long, [{:table, [{"count", :long, 1}, ...]}, ...]}, ...])
    1
  """
  def death_count(headers)
  def death_count(:undefined), do: 0

  def death_count(headers) do
    {_, _, tables} = Enum.find(headers, {"x-death", :long, []}, &({"x-death", _, _} = &1))

    Enum.reduce(tables, 0, fn {:table, values}, acc ->
      {_, _, count} = Enum.find(values, {"count", :long, 0}, &({"count", _, _} = &1))
      acc + count
    end)
  end

  @doc """
  Return exponential delay in milliseconds based in attempted retries.

  ## Examples

    iex> exponential_delay_milliseconds(-1)
    0

    iex> exponential_delay_milliseconds(0)
    1_000

    iex> exponential_delay_milliseconds(2)
    9_000

  """
  def exponential_delay_milliseconds(attempted_retries)
  def exponential_delay_milliseconds(attempted_retries) when attempted_retries < 0, do: 0

  def exponential_delay_milliseconds(attempted_retries) when attempted_retries >= 0 do
    retries = attempted_retries + 1
    retries * retries * 1000
  end

  @doc """
  Message's Routing Key with delay.

  ## Examples

    iex> routing_key("my_app.my_queue", 1000)
    "my_app.my_queue.1000"

  """
  def routing_key(queue, delay), do: "#{queue}.#{delay}"
end
