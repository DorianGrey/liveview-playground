defmodule ElixirPhoenix.Workers.Event do
  @derive Jason.Encoder
  defstruct [:event, :timestamp]

  @type t :: %__MODULE__{
          event: String.t(),
          timestamp: DateTime.t()
        }
end
