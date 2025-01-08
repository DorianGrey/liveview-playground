defmodule ElixirPhoenix.Workers.SampleEventPublisher do
  use Oban.Worker, queue: :default

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Performing sample event publish")
    tag = Base.encode64(:crypto.strong_rand_bytes(16))

    event = %{
      event: tag,
      timestamp: DateTime.utc_now()
    }

    :ok = save_event_to_redis(event)

    topic_key = Application.get_env(:elixir_phoenix, :dashboard_event_topic)
    Phoenix.PubSub.broadcast(ElixirPhoenix.PubSub, topic_key, %{
      event: tag,
      timestamp: DateTime.utc_now()
    })

    :ok
  end

  defp save_event_to_redis(event) do
    event_key = Application.get_env(:elixir_phoenix, :dashboard_event_key)
    json_event = Jason.encode!(event)

    Redix.transaction_pipeline!(:redix, [
      ["LPUSH", event_key, json_event],
      # Only keep the last 10 events
      ["LTRIM", event_key, 0, 9]
    ])

    :ok
  end
end
