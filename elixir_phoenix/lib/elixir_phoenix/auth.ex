defmodule ElixirPhoenix.Auth do
  alias ElixirPhoenix.{Repo, Account, LoginAttempt, WebauthnCredentials, Jwt}
  import Ecto.Query

  require Logger

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
      challenge =
        Wax.new_registration_challenge(
          # Regularly, we have to use ENV to handle this
          rp_id: "localhost",
          origin: "http://localhost:4000",
          timeout: 60000
        )

      {:ok, challenge}
    end
  end

  def complete_registration(
        username,
        generated_user_id,
        challenge,
        challenge_response
      ) do
    # TODO: https://github.com/tanguilp/wax_demo/blob/master/lib/wax_demo_web/controllers/register_key_controller.ex

    Logger.info("Received challenge_response = #{inspect(challenge_response)}")

    %{
      "attestationObject" => attestation_object_b64,
      "clientDataJSON" => client_data_json_raw,
      "rawId" => raw_id_b64,
      "type" => "public-key"
    } = challenge_response

    attestation_object = Base.decode64!(attestation_object_b64)

    case Wax.register(attestation_object, client_data_json_raw, challenge) do
      {:ok, {authenticator_data, result}} ->
        Logger.debug(
          "Wax: attestation object validated with result #{inspect(result)} " <>
            " and authenticator data #{inspect(authenticator_data)}"
        )

        # See https://aaguid.nicolasuter.ch/
        maybe_aaguid = Wax.AuthenticatorData.get_aaguid(authenticator_data)
        Logger.debug("maybe_aaguid=#{inspect(maybe_aaguid)}")

        # This is COSE format, need to store everything.
        public_key =
          CBOR.encode(authenticator_data.attested_credential_data.credential_public_key)

        case Repo.transaction(fn ->
               account_struct =
                 Repo.insert!(
                   %Account{
                     principal: username,
                     generated_id: Base.encode16(generated_user_id)
                   },
                   returning: true
                 )

               Repo.insert!(%WebauthnCredentials{
                 account_id: account_struct.id,
                 credential_id: Base.decode64!(raw_id_b64),
                 public_key: public_key,
                 aaguid: maybe_aaguid
               })

               account_struct
             end) do
          {:ok, account_struct} ->
            Logger.info("Successfully registered user=#{username} on ID=#{account_struct.id}")
            {:ok}

          {:error, details} ->
            Logger.warning("Failed to register user=#{username}")
            {:error, details}
        end

      {:error, e} ->
        {:error, e}
    end
  end

  def start_login(username) do
    account = Repo.get_by(Account, principal: username)

    if account do
      if account.locked_until && DateTime.compare(account.locked_until, DateTime.utc_now()) == :gt do
        {:error, %{code: "ACCOUNT_LOCKED", detail: account.locked_until}}
      else
        case check_rate_limit(account) do
          :ok ->
            # TODO: Maybe set `allowCredentials` explicitly; beware of base64-encoding if so
            # relying_party: %{id: "example.com", name: "ExampleApp"},
            challenge =
              Wax.new_authentication_challenge(
                rp_id: "localhost",
                allow_credentials: [],
                timeout: 60000,
                origin: "http://localhost:4000"
              )

            {:ok, {account.id, challenge}}

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
      "rawId" => credential_id_b64,
      "type" => "public-key",
      "userHandle" => maybe_user_handle_b64
    } = response

    authenticator_data_raw = Base.decode64!(authenticator_data_b64)
    sig_raw = Base.decode64!(sig_b64)
    # TODO: Check if we need this like in ... ever.
    maybe_user_handle =
      if maybe_user_handle_b64 <> "",
        do: Base.decode64!(maybe_user_handle_b64)

    credentials_for_account = credentials_for_account(account_id)
    cred_id_aaguid_mapping = cred_aaguids_for_account(account_id)

    with {:ok, _} <-
           Wax.authenticate(
             credential_id_b64,
             authenticator_data_raw,
             sig_raw,
             client_data_json,
             challenge,
             credentials_for_account
           ),
         :ok <- check_authenticator_status(credential_id_b64, cred_id_aaguid_mapping, challenge),
         {:ok, jwt_token, _} <- create_jwt(account_id) do
      Repo.delete_all(from a in LoginAttempt, where: a.account_id == ^account_id)
      {:ok, %{token: jwt_token}}
    else
      err ->
        Logger.warning("Failed to authenticate: #{inspect(err)}")
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

  defp log_failed_login_attempt(account_id) do
    Repo.insert!(%LoginAttempt{account_id: account_id, attempted_at: DateTime.utc_now()})
  end

  defp credentials_for_account(account_id) do
    credentials =
      Repo.all(
        from c in WebauthnCredentials,
          where: c.account_id == ^account_id,
          select: {c.credential_id, c.public_key}
      )

    Logger.debug("Non-decoded credentials=#{inspect(credentials)}")

    # This code is a bit more noisy, but a lot easier to debug
    decoded_credentials =
      for {credential_id, public_key} <- credentials do
        Logger.debug(
          "Decoding credential_id=#{inspect(credential_id)}, public_key=#{inspect(public_key)}"
        )

        case CBOR.decode(public_key) do
          {:ok, decoded_key, rest} ->
            Logger.debug(
              "Successfully decoded key=#{inspect(decoded_key)}, rest=#{inspect(rest)}"
            )

            {Base.encode64(credential_id), decoded_key}

          {:error, reason} ->
            Logger.debug("Failed to decode: #{inspect(reason)}")
            nil
        end
      end
      |> Enum.filter(& &1)

    Logger.debug("Credentials for account=#{account_id}: #{inspect(decoded_credentials)}")
    decoded_credentials
  end

  defp cred_aaguids_for_account(account_id) do
    aaguid_mapping_raw =
      Repo.all(
        from c in WebauthnCredentials,
          where: c.account_id == ^account_id,
          select: {c.credential_id, c.aaguid}
      )

    aaguid_mapping =
      for {credential_id, aaguid} <- aaguid_mapping_raw, into: %{} do
        {Base.encode64(credential_id), aaguid}
      end

    Logger.debug("AAGUIDs for account=#{account_id}: #{inspect(aaguid_mapping)}")
    aaguid_mapping
  end

  defp check_authenticator_status(credential_id, cred_id_aaguid_mapping, challenge) do
    case cred_id_aaguid_mapping[credential_id] do
      nil ->
        :ok

        aaguid ->
        case Wax.Metadata.get_by_aaguid(aaguid, challenge) do
          {:ok, _} ->
            :ok

          {:error, %Wax.MetadataStatementNotFoundError{}} ->
            # Note: Even if the Wax service to update stuff from the official FIDO alliance
            # web resources, quite a few soft authenticators / tokens (e.g. tools like Bitwarden or 1Password)
            # are NOT listed there.
            Logger.info("Did not find any metadata to validate against for AAGUID=#{inspect(aaguid)}, accepting it.")
            :ok

          {:error, _} = error ->
            error
        end
    end
  end
end
