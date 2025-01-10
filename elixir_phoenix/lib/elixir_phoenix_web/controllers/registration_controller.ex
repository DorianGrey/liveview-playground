defmodule ElixirPhoenixWeb.RegistrationController do
  use ElixirPhoenixWeb, :live_view

  alias ElixirPhoenix.Auth

  require Logger

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
    <div id="webauthn-registration" phx-hook="WebAuthnRegistrationHook"></div>
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
    generated_user_id = :crypto.strong_rand_bytes(16)

    case Auth.start_registration(login) do
      {:ok, challenge} ->
        res =
          socket
          |> assign(username: login, challenge: challenge, generated_user_id: generated_user_id)
          |> push_event(
            "webauthn:start-registration",
            %{
              login: login,
              challenge: Base.encode64(challenge.bytes),
              rp_id: challenge.rp_id,
              user: login,
              user_id: Base.encode64(generated_user_id),
              attestation: challenge.attestation,
              timeout: Application.get_env(:elixir_phoenix, :webauthn_timeout_ms)
            }
          )

        {:noreply, res}

      {:error, detail} ->
        {:noreply, assign(socket, :error, "#{inspect(detail)}")}
    end
  end

  def handle_event("finish_registration", %{"response" => response}, socket) do
    challenge = socket.assigns.challenge
    username = socket.assigns.username
    generated_user_id = socket.assigns.generated_user_id

    case Auth.complete_registration(
           username,
           generated_user_id,
           challenge,
           response
         ) do
      {:ok} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Registered successfully!")
          |> push_navigate(to: "/login")
        }

      {:error, details} ->
        {:noreply, assign(socket, :error, "#{inspect(details)}")}
    end
  end
end
