defmodule ElixirPhoenix.Workers.SampleEventPublisher do
  alias ElixirPhoenix.Workers.Event
  use Oban.Worker, queue: :default

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.debug("Performing sample event publish")
    tag = to_fingerprint(:crypto.strong_rand_bytes(16))

    event = %Event{
      event: tag,
      timestamp: DateTime.utc_now()
    }

    Logger.debug("Publishing event=#{inspect(event)}")

    :ok = save_event(event)

    topic_key = Application.get_env(:elixir_phoenix, :dashboard_event_topic)

    Phoenix.PubSub.broadcast(ElixirPhoenix.PubSub, topic_key, %{
      event: tag,
      timestamp: DateTime.utc_now()
    })

    :ok
  end

  @spec save_event(Event.t()) :: :ok
  defp save_event(event) do
    event_key = Application.get_env(:elixir_phoenix, :dashboard_event_key)

    case Jason.encode(event) do
      {:ok, serialized_event} ->
        persist_event(event_key, serialized_event)

      {:error, err} ->
        Logger.warning("Failed to serialize event for persisting, reason=#{inspect(err)}")
    end

    :ok
  end

  defp persist_event(event_key, serialized_event) do
    case Redix.transaction_pipeline(:redix, [
           ["LPUSH", event_key, serialized_event],
           # Only keep the last 10 events
           ["LTRIM", event_key, 0, 9]
         ]) do
      {:ok, _} -> Logger.debug("Event stored successfully")
      {:error, err} -> Logger.warning("Failed to store event, reason=#{inspect(err)}")
    end
  end

  @spec to_fingerprint(binary()) :: String.t()
  defp to_fingerprint(byte_source) do
    byte_source
    |> :binary.bin_to_list()
    |> Enum.map(&Integer.to_string(&1, 16))
    |> Enum.map(&String.pad_leading(&1, 2, "0"))
    |> Enum.map(&String.upcase/1)
    |> Enum.join(":")
  end
end
