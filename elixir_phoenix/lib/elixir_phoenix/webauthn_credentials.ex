defmodule ElixirPhoenix.WebauthnCredentials do
  use Ecto.Schema
  import Ecto.Changeset

  schema "webauthn_credentials" do
    field :public_key, :binary
    field :account_id, :integer
    field :credential_id, :binary
    field :aaguid, :binary
    field :sign_count, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(webauthn_credentials, attrs) do
    webauthn_credentials
    |> cast(attrs, [:account_id, :credential_id, :public_key, :aaguid, :sign_count])
    |> validate_required([:account_id, :credential_id, :public_key, :aaguid, :sign_count])
  end
end
