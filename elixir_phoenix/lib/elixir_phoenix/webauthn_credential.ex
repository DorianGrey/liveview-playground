defmodule ElixirPhoenix.WebauthnCredential do
  use Ecto.Schema
  import Ecto.Changeset

  schema "webauthn_credential" do
    field :public_key, :binary
    field :account_id, :integer
    field :credential_id, :binary
    field :sign_count, :integer

    timestamps()
  end

  @doc false
  def changeset(webauthn_credential, attrs) do
    webauthn_credential
    |> cast(attrs, [:account_id, :credential_id, :public_key, :sign_count])
    |> validate_required([:account_id, :credential_id, :public_key, :sign_count])
  end
end
