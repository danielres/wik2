defmodule Wik.Updates.Update do
  @moduledoc false

  @enforce_keys [:merged_on, :pr_number, :sections]
  defstruct [:merged_on, :pr_number, :sections]

  @type section :: %{
          required(:category) => String.t(),
          required(:items) => [String.t()]
        }

  @type t :: %__MODULE__{
          merged_on: Date.t(),
          pr_number: pos_integer(),
          sections: [section()]
        }
end
