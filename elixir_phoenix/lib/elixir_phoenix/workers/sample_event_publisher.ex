defmodule ElixirPhoenix.Workers.SampleEventPublisher do
  use Oban.Worker, queue: :default

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Performing sample event publish")
    tag = Base.encode64(:crypto.strong_rand_bytes(16))

    Phoenix.PubSub.broadcast(ElixirPhoenix.PubSub, "dashboard-events:updates", %{
      event: tag,
      timestamp: DateTime.utc_now()
    })

    :ok
  end
end
