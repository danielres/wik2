defmodule Qblog.Blocks.Types.Behaviour do
  @moduledoc """
  Callback contract for block type modules.

  `Qblog.Blocks.Types` uses this shared interface to route block lifecycle
  operations to each concrete block type.
  """

  @callback label() :: String.t()
  @callback type() :: atom()
  @callback default_data() :: map()
  @callback block_to_form_params(block :: term(), params :: map(), page_tree :: term()) :: map()
  @callback update_block(block :: term(), params :: map(), opts :: Keyword.t()) ::
              {:ok, term()} | {:error, term()}
  @callback validate_data(data :: term()) :: :ok | {:error, Keyword.t()}
end
