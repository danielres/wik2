defmodule Wik.Types.Slug do
  use Ash.Type.NewType,
    subtype_of: :string,
    constraints: [match: ~r/^[a-z0-9](?:[a-z0-9_-]*[a-z0-9])?$/]
end
