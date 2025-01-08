defmodule ElixirPhoenixWeb.LoginController do
  use ElixirPhoenixWeb, :live_view

  alias ElixirPhoenix.Auth

  require Logger

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
    <div id="webauthn-registration" phx-hook="LoginHook"></div>
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
      # TODO: Check login on Wax example
      # TODO: Check warning
      {:ok, {account_id, challenge}} ->
        {
          :noreply,
          socket
          |> assign(account_id: account_id, challenge: challenge)
          |> push_event(
            "webauthn:start-login",
            %{
              challenge: Base.encode64(challenge.bytes),
              rp_id: challenge.rp_id,
              timeout: 60000
            }
          )
        }

      {:error, %{:code => code, :detail => detail}} ->
        {:noreply, socket |> assign(:error, "#{code} #{inspect(detail)}")}
    end
  end

  def handle_event("finish_login", %{"response" => response}, socket) do
    # TODO: Ya... needs rework
    # See https://github.com/tanguilp/wax_demo/blob/master/lib/wax_demo_web/controllers/credential_controller.ex
    challenge = socket.assigns.challenge
    account_id = socket.assigns.account_id
    Logger.debug("Finishing login using challenge=#{inspect(challenge)}")
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
