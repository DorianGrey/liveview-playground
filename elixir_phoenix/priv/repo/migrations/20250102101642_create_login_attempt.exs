defmodule ElixirPhoenix.Repo.Migrations.CreateLoginAttempts do
  use Ecto.Migration

  def change do
    create table(:login_attempt) do
      add :account_id, references(:account, on_delete: :delete_all), null: false
      add :attempted_at, :utc_datetime_usec

      timestamps(type: :timestamptz)
    end
  end
end
