defmodule ElixirPhoenixWeb.LoginController do
  use ElixirPhoenixWeb, :live_view

  def render(assigns) do
    ~H"""
    <div class="mx-auto my-20">
      <.form for={@form} phx-submit="submit" phx-change="validate">
        <.input required field={@form[:login]} phx-debounce="blur" label="Username" />
        <.button type="submit" class="mt-8 disabled:opacity-25 disabled:pointer-events-none" disabled={@invalid}>Submit</.button>
      </.form>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    # Let's assume a fixed temperature for now
    temperature = 70
    form = to_form(%{"login" => ""})

    updated =
      assign(socket, :temperature, temperature)
      |> assign(:form, form)
      |> assign(:invalid, true)

    {:ok, updated}
  end

  def handle_event("validate", %{"login" => login}, socket) do
    invalid = login |> String.trim() == ""
    {:noreply, assign(socket, :invalid, invalid)}
  end

  def handle_event("submit", _params, socket) do
    IO.puts(socket.assigsn.form)
    {:noreply, socket}
  end
end
