defmodule ElixirPhoenixWeb.RegistrationController do
  use ElixirPhoenixWeb, :live_view

  alias ElixirPhoenix.Auth

  def render(assigns) do
    ~H"""
    <div class="mx-auto my-20">
      <.form for={@form} phx-submit="submit" phx-change="validate">
        <.input required field={@form[:login]} phx-debounce="blur" label="Username" />
        <.button type="submit" class="mt-8" disabled={@invalid}>
          Register
        </.button>
        <%= if @error do %>
          <p class="text-red-700">{@error}</p>
        <% end %>
      </.form>
    </div>
    <script>
      window.addEventListener("webauthn:start-registration", async (event) => {
        const {challenge} = event.detail;
        try {
          // TODO: Check if this is technically correct
          const assertion = await navigator.credentials.create({
            publicKey: challenge
          });

          // Contains a https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential

          LiveSocket.execJS(
            document,
            `phx-hook="finish_registration"`,
            {detail: {response: assertion}}
          );
        }
      });
    </script>
    """
  end

  def mount(_params, _session, socket) do
    form = to_form(%{"login" => ""})

    {:ok,
     socket
     |> assign(form: form, invalid: true, error: nil)}
  end

  def handle_event("validate", %{"login" => login}, socket) do
    invalid = login |> String.trim() == ""
    {:noreply, assign(socket, :invalid, invalid)}
  end

  def handle_event("submit", %{"login" => login}, socket) do
    case Auth.start_registration(login) do
      {:ok, challenge} ->
        socket
        |> assign(username: login, challenge: challenge)
        |> push_event("webauthn:start-registration", %{options: Base.encode64(challenge)})
    end
  end

  def handle_event("finish_registration", %{"response" => response}, socket) do
    # TODO
    challenge = socket.assigns.challenge
    username = socket.assigns.username
  end
end
