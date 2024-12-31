defmodule ElixirPhoenix.Auth do
  alias ElixirPhoenix.{Repo, Account, LoginAttempt, WebauthnCredential, Jwt}
  import Ecto.Query

  # seconds
  @rate_limit_window 60
  @max_attempts 5
  # 15 min lockout if attempted too often in a row
  @lockout_duration 900

  def create_jwt(account_id) do
    Jwt.generate_and_sign(%{"user_id" => account_id})
  end

  def verify_jwt(token) do
    Jwt.verify_and_validate(token)
  end

  def start_registration(username) do
    account_exists = Repo.exists?(from a in Account, where: a.principal == ^username)

    if account_exists do
      # TODO: Ya... a bit unlikely to expose this detail.
      {:error, "ACCOUNT_EXISTS"}
    else
      challenge = Wax.new_registration_challenge(timeout: 60000)
      {:ok, challenge}
    end
  end

  def complete_registration(username, challenge, challenge_response) do
    # TODO: https://github.com/tanguilp/wax_demo/blob/master/lib/wax_demo_web/controllers/register_key_controller.ex
  end

  @spec start_login(any()) :: {:error, %{code: <<_::80, _::_*32>>, detail: any()}}
  def start_login(username) do
    account = Repo.get_by(Account, principal: username)

    if account do
      if account.locked_until && DateTime.compare(account.locked_until, DateTime.utc_now()) == :gt do
        {:error, %{code: "ACCOUNT_LOCKED", detail: account.locked_until}}
      else
        case check_rate_limit(account) do
          :ok ->
            credentials =
              Repo.all(
                from c in WebauthnCredential,
                  where: c.account_id == ^account.id,
                  select: c.credential_id
              )

            # relying_party: %{id: "example.com", name: "ExampleApp"},
            challenge =
              Wax.new_authentication_challenge(
                allow_credentials: credentials,
                timeout: 60000
              )

            {:ok, %{account_id: account.id, challenge: challenge}}

          # TODO: Check warning
          {:error, details} ->
            {:error, details}
        end
      end
    else
      {:error, %{code: "NO_ACCOUNT", detail: nil}}
    end
  end

  def finish_login(account_id, response, challenge) do
    # TODO: Check via https://hexdocs.pm/wax_/Wax.html#authenticate/5
    # TODO: Check if datastructure is correct
    %{
      "clientDataJSON" => client_data_json,
      "authenticatorData" => authenticator_data_b64,
      "sig" => sig_b64,
      "rawID" => credential_id,
      "type" => "public-key",
      "userHandle" => maybe_user_handle_b64
    } = response

    authenticator_data_raw = Base.decode64!(authenticator_data_b64)
    sig_raw = Base.decode64!(sig_b64)
    # TODO: Check if we need this
    maybe_user_handle = if maybe_user_handle_b64 <> "", do: Base.decode64!(maybe_user_handle_b64)
    credentials_from_user_id = credentials_from_user_id(maybe_user_handle)

    cred_id_aaguid_mapping = cred_mapping_from_user_handle(maybe_user_handle)

    with {:ok, _} <-
           Wax.authenticate(
             credential_id,
             authenticator_data_raw,
             sig_raw,
             client_data_json,
             challenge,
             credentials_from_user_id
           ),
         :ok <- check_authenticator_status(credential_id, cred_id_aaguid_mapping, challenge) do
      Repo.delete_all(from a in LoginAttempt, where: a.account_id == ^account_id)
      {:ok, %{token: create_jwt(account_id)}}
    else
      err ->
        log_failed_login_attempt(account_id)
        err
    end
  end

  defp check_rate_limit(account) do
    one_minute_ago = DateTime.utc_now() |> DateTime.add(-@rate_limit_window, :second)

    query =
      from a in LoginAttempt,
        where: a.account_id == ^account.id and a.attempted_at >= ^one_minute_ago

    recent_failure_count =
      Repo.aggregate(
        query,
        :count
      )

    if recent_failure_count >= @max_attempts do
      locked_until = DateTime.utc_now() |> DateTime.add(@lockout_duration, :second)
      Repo.update!(%Account{account | locked_until: locked_until})

      {:error,
       "Too many attempts within #{@rate_limit_window}. Account locked until #{locked_until}."}
    else
      :ok
    end
  end

  defp log_failed_login_attempt(account) do
    Repo.insert!(%LoginAttempt{account_id: account.id, attempted_at: DateTime.utc_now()})
  end

  defp credentials_from_user_id(nil) do
    []
  end

  # TODO: Real impl
  defp credentials_from_user_id(user_id) do
    # for {_, _, cred_id, cose_key, _} <- WaxDemo.User.get_by_user_id(user_id) do
    #  {cred_id, cose_key}
    # end
    []
  end

  defp cred_mapping_from_user_handle(nil) do
    []
  end

  defp cred_mapping_from_user_handle(user_id) do
    # TODO: Real impl
    # for {_, _, cred_id, _, maybe_aaguid} <- WaxDemo.User.get_by_user_id(user_id), into: %{} do
    #  {cred_id, maybe_aaguid}
    # end
    []
  end

  defp check_authenticator_status(credential_id, cred_id_aaguid_mapping, challenge) do
    case cred_id_aaguid_mapping[credential_id] do
      nil ->
        :ok

      aaguid ->
        case Wax.Metadata.get_by_aaguid(aaguid, challenge) do
          {:ok, _} ->
            :ok

          {:error, _} = error ->
            error
        end
    end
  end
end
