defmodule ElixirPhoenix.Auth do
  @moduledoc """
  Implements the authorization features required / intended for this app, namely:
  - Login
  - Registration
  - JWT generation & validation
  """
  alias ElixirPhoenix.{Repo, Account, LoginAttempt, WebauthnCredentials, Jwt}
  alias ElixirPhoenix.Auth.AuthError
  import Ecto.Query

  require Logger

  # seconds
  @rate_limit_window 60
  @max_attempts 5
  # 15 min lockout if attempted too often in a row
  @lockout_duration 900

  @spec create_jwt(non_neg_integer()) ::
          {:ok, Joken.bearer_token(), Joken.claims()} | {:error, Joken.error_reason()}
  def create_jwt(account_id) do
    Jwt.generate_and_sign(%{"user_id" => account_id})
  end

  @spec verify_jwt(Joken.bearer_token()) ::
          {:ok, Joken.claims()} | {:error, Joken.error_reason()}
  def verify_jwt(token) do
    Jwt.verify_and_validate(token)
  end

  @spec start_registration(String.t()) :: {:ok, Wax.Challenge.t()} | {:error, String.t()}
  def start_registration(username) do
    account_exists = Repo.exists?(from a in Account, where: a.principal == ^username)

    if account_exists do
      # Ya... a bit unlikely to expose this detail. Would not do that in production.
      {:error, "ACCOUNT_EXISTS"}
    else
      challenge =
        Wax.new_registration_challenge(
          # Regularly, we have to use ENV to handle this
          rp_id: Application.get_env(:elixir_phoenix, :webauthn_rp_id),
          origin: Application.get_env(:elixir_phoenix, :webauthn_origin),
          timeout: Application.get_env(:elixir_phoenix, :webauthn_timeout_ms)
        )

      {:ok, challenge}
    end
  end

  # TODO : More accurate types on "challenge_response"
  @spec complete_registration(String.t(), binary(), Wax.Challenge.t(), map()) ::
          {:ok} | {:error, any()}
  def complete_registration(
        username,
        generated_user_id,
        challenge,
        %{
          "attestationObject" => attestation_object_b64,
          "clientDataJSON" => client_data_json_raw,
          "rawId" => raw_id_b64,
          "type" => "public-key"
        }
      ) do
    # Based on: https://github.com/tanguilp/wax_demo/blob/master/lib/wax_demo_web/controllers/register_key_controller.ex

    attestation_object = Base.decode64!(attestation_object_b64)

    case Wax.register(attestation_object, client_data_json_raw, challenge) do
      {:ok, {authenticator_data, result}} ->
        Logger.debug(
          "Wax: attestation object validated with result #{inspect(result)} " <>
            " and authenticator data #{inspect(authenticator_data)}"
        )

        # See https://aaguid.nicolasuter.ch/
        maybe_aaguid = Wax.AuthenticatorData.get_aaguid(authenticator_data)

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

  @spec start_login(String.t()) ::
          {:ok, {non_neg_integer(), Wax.Challenge.t()}} | {:error, %AuthError{}}
  def start_login(username) do
    # TODO: Fix dialyzer; still complains about s.th. that ends up here. Has to do with
    # some of the `Repo` functions returning a `term()` which is just another way to tell
    # "I don't known what is returned, might be anything".
    # Aims at both `find_account_by_principal` and `start_login_for_account`.
    account = find_account_by_principal(username)

    if account do
      start_login_for_account(account)
    else
      {:error, %AuthError{code: "NO_ACCOUNT", detail: nil}}
    end
  end

  @spec find_account_by_principal(String.t()) :: %Account{} | nil
  defp find_account_by_principal(username) do
    Account |> Repo.get_by(principal: username)
  end

  @spec start_login_for_account(%Account{}) ::
          {:ok, {non_neg_integer(), Wax.Challenge.t()}} | {:error, %AuthError{}}
  defp start_login_for_account(account) do
    if account.locked_until && DateTime.compare(account.locked_until, DateTime.utc_now()) == :gt do
      {:error, %AuthError{code: "ACCOUNT_LOCKED", detail: account.locked_until}}
    else
      case check_rate_limit(account) do
        :ok ->
          # TODO: Maybe set `allowCredentials` explicitly; beware of base64-encoding if so
          # relying_party: %{id: "example.com", name: "ExampleApp"},
          challenge =
            Wax.new_authentication_challenge(
              rp_id: Application.get_env(:elixir_phoenix, :webauthn_rp_id),
              allow_credentials: [],
              timeout: Application.get_env(:elixir_phoenix, :webauthn_timeout_ms),
              origin: Application.get_env(:elixir_phoenix, :webauthn_origin)
            )

          {:ok, {account.id, challenge}}

        other ->
          other
      end
    end
  end

  @spec finish_login(non_neg_integer(), map(), %Wax.Challenge{}) ::
          {:ok, %{token: Joken.bearer_token()}} | {:error, any()}
  def finish_login(
        account_id,
        %{
          "clientDataJSON" => client_data_json,
          "authenticatorData" => authenticator_data_b64,
          "sig" => sig_b64,
          "rawId" => credential_id_b64,
          "type" => "public-key"
          # "userHandle" => maybe_user_handle_b64
        },
        challenge
      ) do
    # See https://hexdocs.pm/wax_/Wax.html#authenticate/5

    authenticator_data_raw = Base.decode64!(authenticator_data_b64)
    sig_raw = Base.decode64!(sig_b64)
    # TODO: Check if we need this like in ... ever.
    # maybe_user_handle =
    #   if maybe_user_handle_b64 <> "",
    #     do: Base.decode64!(maybe_user_handle_b64)

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
        Logger.warning("Failed to authenticate account=#{account_id}: #{inspect(err)}")
        log_failed_login_attempt(account_id)
        err
    end
  end

  @spec check_rate_limit(%Account{}) :: :ok | {:error, %AuthError{}}
  defp check_rate_limit(account) do
    recent_failure_count = get_recent_failure_count(account)

    if recent_failure_count >= @max_attempts do
      locked_until = DateTime.utc_now() |> DateTime.add(@lockout_duration, :second)
      updated_account = Account.changeset(account, %{locked_until: locked_until})
      Repo.update!(updated_account)

      {
        :error,
        %AuthError{
          code:
            "Too many attempts within #{@rate_limit_window}. Account locked until #{locked_until}."
        }
      }
    else
      :ok
    end
  end

  @spec get_recent_failure_count(%Account{}) :: non_neg_integer()
  defp get_recent_failure_count(account) do
    one_minute_ago = DateTime.utc_now() |> DateTime.add(-@rate_limit_window, :second)

    query =
      from a in LoginAttempt,
        where: a.account_id == ^account.id and a.attempted_at >= ^one_minute_ago

    Repo.aggregate(
      query,
      :count
    ) || 0
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
            # web resources (once I get the config right, though), soft authenticators / tokens
            # (e.g. tools like Bitwarden or 1Password) are not always listed there, or become
            # listed with a delay (they just pop up to frequently).
            Logger.info(
              "Did not find any metadata to validate against for AAGUID=#{inspect(aaguid)}, accepting it."
            )

            :ok

          {:error, _} = error ->
            error
        end
    end
  end
end
