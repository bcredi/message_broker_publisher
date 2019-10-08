defmodule MessageBroker.Publisher.Migrations do
  @moduledoc false

  use Ecto.Migration

  @table_name "message_broker_events"
  @function_name "notify_events_creation"
  @notification_channel "event_created"
  @trigger_name "event_created"

  def up do
    create table(:message_broker_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:publisher_name, :string)
      add(:event_name, :string)
      add(:payload, :map)

      timestamps()
    end

    execute("""
      CREATE OR REPLACE FUNCTION #{@function_name}()
      RETURNS trigger AS $$
      BEGIN
        PERFORM pg_notify(
          '#{@notification_channel}',
          json_build_object(
            'record', row_to_json(NEW)
          )::text
        );
        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
    """)

    execute("DROP TRIGGER IF EXISTS #{@trigger_name} ON #{@table_name}")

    execute("""
      CREATE TRIGGER #{@trigger_name}
      AFTER INSERT
      ON #{@table_name}
      FOR EACH ROW
      EXECUTE PROCEDURE #{@function_name}()
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS #{@trigger_name} ON #{@table_name}")
    execute("DROP FUNCTION IF EXISTS #{@function_name} CASCADE")
    drop(table(:message_broker_events))
  end
end
