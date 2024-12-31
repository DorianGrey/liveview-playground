defmodule ElixirPhoenix.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "account" do
    field :principal, :string
    field :locked_until, :utc_datetime
    timestamps()
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:principal])
    |> validate_required([:principal])
  end
end
