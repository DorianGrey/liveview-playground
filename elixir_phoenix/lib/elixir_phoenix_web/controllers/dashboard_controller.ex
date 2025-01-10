defmodule ElixirPhoenixWeb.DashboardController do
  use ElixirPhoenixWeb, :live_view

  require Logger

  @impl true
  def render(assigns) do
    ~H"""
    <%= if @events == [] do %>
      <p>No events tracked yet.</p>
    <% else %>
      <table class="table-auto border-collapse">
        <caption class="caption-top">Latest 10 events</caption>
        <thead>
          <th class="p2 border border-slate-500">Tag</th>
          <th class="p2 border border-slate-500">Timestamp</th>
        </thead>
        <tbody>
          <%= for event <- @events do %>
            <tr>
              <td class="p-2 border border-slate-600">{event.event}</td>
              <td class="p-2 border border-slate-600">{event.timestamp}</td>
            </tr>
          <% end %>
        </tbody>
      </table>
    <% end %>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      topic_key = Application.get_env(:elixir_phoenix, :dashboard_event_topic)
      # Unsub takes place automatically when process shuts down
      Phoenix.PubSub.subscribe(ElixirPhoenix.PubSub, topic_key)
    end

    events = fetch_initial_events()
    Logger.debug("Found initial events=#{inspect(events)}")

    {:ok, assign(socket, events: events)}
  end

  @impl true
  @spec handle_info(%{:event => any(), :timestamp => any(), optional(any()) => any()}, any()) ::
          {:noreply, any()}
  def handle_info(%{event: event, timestamp: timestamp}, socket) do
    Logger.info("Received event=#{inspect(event)} w/ timestamp=#{inspect(timestamp)}")

    events =
      [%{event: event, timestamp: timestamp} | socket.assigns.events]
      |> Enum.take(10)

    {:noreply, assign(socket, events: events)}
  end

  defp fetch_initial_events do
    event_key = Application.get_env(:elixir_phoenix, :dashboard_event_key)

    Redix.command!(:redix, ["LRANGE", event_key, 0, 9])
    # Important: Keys are en-/decoded as strings by default, need to deal with this
    |> Enum.map(&Jason.decode!(&1, keys: :atoms))
  end
end
