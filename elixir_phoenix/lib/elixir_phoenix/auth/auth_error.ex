defmodule ElixirPhoenix.Auth.AuthError do
  @type t :: %{
          code: String.t(),
          detail: DateTime.t() | nil
        }
  defstruct [:code, :detail]
end
