defmodule ElixirPhoenix.Repo.Migrations.CreateWebauthnCredential do
  use Ecto.Migration

  def change do
    create table(:webauthn_credentials) do
      add :account_id, references(:account, on_delete: :delete_all), null: false
      add :credential_id, :binary, null: false
      add :public_key, :binary, null: false
      add :sign_count, :integer, default: 0, null: false

      timestamps(type: :timestamptz)
    end

    create unique_index(:webauthn_credentials, [:credential_id])
  end
end
