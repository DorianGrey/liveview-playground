defmodule ElixirPhoenix.Repo.Migrations.CreateAccount do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION citext", "DROP EXTENSION citext"

    create table(:account) do
      add :principal, :citext, null: false
      add :generated_id, :string, null: false
      add :locked_until, :timestamptz
      timestamps(type: :timestamptz)
    end

    create unique_index(:account, [:principal])
  end
end
