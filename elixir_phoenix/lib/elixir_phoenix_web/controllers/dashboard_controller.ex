defmodule ElixirPhoenixWeb.DashboardController do
  use ElixirPhoenixWeb, :live_view

  def render(assigns) do
    # TODO: Actual impl.
    ~H"""
    <div>Some fancy dashboard here!</div>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, socket}
  end
end
