defmodule Qblog.Blocks.Types.Behaviour do
  @moduledoc """
  Callback contract for block type modules.

  `Qblog.Blocks.Types` uses this shared interface to route block lifecycle
  operations to each concrete block type.
  """

  @callback block_to_form_params(block :: term(), params :: map(), page_tree :: term()) :: map()
  @callback create_initial_version(block :: term(), opts :: Keyword.t()) :: :ok | {:error, term()}
  @callback default_data() :: map()
  @callback label() :: String.t()
  @callback supports_history?() :: boolean()
  @callback supports_title?() :: boolean()
  @callback type() :: atom()
  @callback update_block(block :: term(), params :: map(), opts :: Keyword.t()) ::
              {:ok, term()} | {:error, term()}
  @callback validate_data(data :: term()) :: :ok | {:error, Keyword.t()}
  @callback version_to_text(block :: term(), version :: term(), opts :: Keyword.t()) ::
              {:ok, String.t()} | {:error, term()}
end
