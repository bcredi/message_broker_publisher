defmodule MessageBroker.Publisher.EventBuilder do
  @moduledoc """
  Event builder for the message broker context.
  Use the `EventBuilder` to define new events. It's a small wraper around the `Event.changeset/2`.

  ## Options
    * `:as` — the event name.

  ## Examples

      defmodule MyEvent do
        use MessageBroker.Publisher.EventBuilder, as: "my_event"

        defstruct [:key1, :key2]
      end

  After define the `MyEvent` module, we can build events using maps or structs as follow:

      iex> MyEvent.new(%SomeStruct{key1: "1", key2: "2"})
      %Ecto.Changeset{
        action: nil,
        changes: %{
          event_name: "my_event",
          payload: %MyEvent{
            key1: "1",
            key2: "2"
          }
        },
        errors: [],
        data: #Event<>,
        valid?: true
      }

      iex> MyEvent.new(%{key1: "1", key2: "2"})
      %Ecto.Changeset{
        action: nil,
        changes: %{
          event_name: "my_event",
          payload: %MyEvent{
            key1: "1",
            key2: "2"
          }
        },
        errors: [],
        data: #Event<>,
        valid?: true
      }

  """

  alias MessageBroker.Publisher.Event

  defmacro __using__(as: event_name) when is_bitstring(event_name) do
    quote do
      @doc """
      Build a new event changeset ready for insertion into the database.

      ## Examples

          iex> new(%SomeStruct{key: "value"})
          %Ecto.Changeset{}

          iex> new(%{key: "value"})
          %Ecto.Changeset{}

      """
      @spec new(struct | map) :: Ecto.Changeset.t()
      def new(%_{} = struct), do: build_event_from_struct(struct)
      def new(%{} = map), do: build_event_from_map(map)

      defp build_event_from_struct(%_{} = schema) do
        attrs = %{
          event_name: unquote(event_name),
          payload: struct(__MODULE__, Map.from_struct(schema))
        }

        Event.changeset(%Event{}, attrs)
      end

      defp build_event_from_map(%{} = map) do
        attrs = %{
          event_name: unquote(event_name),
          payload: struct(__MODULE__, map)
        }

        Event.changeset(%Event{}, attrs)
      end
    end
  end
end
