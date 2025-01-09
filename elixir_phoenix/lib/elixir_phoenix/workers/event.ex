defmodule ElixirPhoenix.Workers.Event do
  defstruct [:event, :timestamp]

  @type t :: %__MODULE__{
          event: String.t(),
          timestamp: DateTime.t()
        }
end
