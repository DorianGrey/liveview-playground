defmodule ElixirPhoenix.Account do
  use Ecto.Schema
  import Ecto.Changeset

  schema "account" do
    field :principal, :string
    field :generated_id, :string
    field :locked_until, :utc_datetime_usec
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [:principal, :generated_id])
    |> validate_required([:principal, :generated_id])
  end
end
