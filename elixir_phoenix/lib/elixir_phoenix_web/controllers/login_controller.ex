defmodule ElixirPhoenixWeb.LoginController do
  use ElixirPhoenixWeb, :live_view

  alias ElixirPhoenix.Auth

  def render(assigns) do
    ~H"""
    <div class="mx-auto my-20">
      <.form for={@form} phx-submit="submit" phx-change="validate">
        <.input required field={@form[:login]} phx-debounce="blur" label="Username" />
        <.button type="submit" class="mt-8" disabled={@invalid}>
          Submit
        </.button>
        <%= if @error do %>
          <p class="text-red-700">{@error}</p>
        <% end %>
      </.form>
    </div>
    <script>
      window.addEventListener("webauthn:start-login", async (event) => {
        const {challenge} = event.detail;
        try {
          // TODO: Check if this is technically correct
          const assertion = await navigator.credentials.get({
            publicKey: challenge
          });

          // Contains a https://developer.mozilla.org/en-US/docs/Web/API/PublicKeyCredential

          LiveSocket.execJS(
            document,
            `phx-hook="finish_login"`,
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
    case Auth.start_login(login) do
      # TODO: Check warning
      {:ok, %{:account_id => account_id, :challenge => challenge}} ->
        socket
        |> assign(account_id: account_id, challenge: challenge)
        |> push_event("webauthn:start-login", %{options: Base.encode64(challenge)})

      {:error, %{:code => code, :detail => detail}} ->
        socket |> assign(:error, "#{code} #{inspect(detail)}")
    end
  end

  def handle_event("finish_login", %{"response" => response}, socket) do
    challenge = socket.assigns.challenge
    account_id = socket.assigns.account_id
    # TODO: Fill.
    case Auth.finish_login(account_id, response, challenge) do
      {:ok, %{:token => token}} ->
        # TODO: Generate jwt token and set via redirect
        # put_resp_cookie("auth_token", token, http_only: true, max_age: 60 * 60 * 24)
        {:noreply, push_navigate(socket, to: "/set_jwt_cookie_and_redirect?jwt=#{token}")}

      {:error, reason} ->
        {:noreply, socket |> assign(:error, "#{inspect(reason)}")}
    end
  end
end
