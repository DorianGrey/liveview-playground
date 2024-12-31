defmodule ElixirPhoenix.LoginAttempt do
  use Ecto.Schema
  import Ecto.Changeset

  schema "login_attempt" do
    field :account_id, :integer
    field :attempted_at, :utc_datetime_usec

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(login_attempt, attrs) do
    login_attempt
    |> cast(attrs, [:account_id, :attempted_at])
    |> validate_required([:account_id, :attempted_at])
  end
end
