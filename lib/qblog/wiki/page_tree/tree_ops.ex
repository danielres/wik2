defmodule Qblog.Wiki.PageTree.TreeOps do
  alias Qblog.Wiki.PageTree.TreeOps.CreateByPath

  defdelegate create_node_at_path(nodes, path, attrs \\ %{}), to: CreateByPath, as: :call
end
