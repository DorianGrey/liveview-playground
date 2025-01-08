defmodule ElixirPhoenixWeb.DashboardController do
  use ElixirPhoenixWeb, :live_view

  require Logger

  @impl true
  def render(assigns) do
    # TODO: Actual impl.
    ~H"""
    <%= if @events == [] do %>
      <p>No events tracked yet.</p>
    <% else %>
      <table class="table-auto border-collapse">
        <caption class="caption-top">Events received since login</caption>
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
    if connected?(socket),
      do: Phoenix.PubSub.subscribe(ElixirPhoenix.PubSub, "dashboard-events:updates")

    {:ok, assign(socket, events: [])}
  end

  @impl true
  def handle_info(%{event: event, timestamp: timestamp}, socket) do
    Logger.info("Received event=#{inspect(event)} w/ timestamp=#{inspect(timestamp)}")

    events = [%{event: event, timestamp: timestamp} | socket.assigns.events]
    {:noreply, assign(socket, events: events)}
  end
end
