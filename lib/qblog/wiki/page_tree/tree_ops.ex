defmodule Qblog.Wiki.PageTree.TreeOps do
  alias Qblog.Wiki.PageTree.TreeOps.CreateNodeAtPath

  defdelegate create_node_at_path(nodes, path, attrs \\ %{}), to: CreateNodeAtPath, as: :call
end
