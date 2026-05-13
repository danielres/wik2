defmodule Wik.Types.Slug do
  use Ash.Type.NewType,
    subtype_of: :string,
    constraints: [match: Utils.Slugify.match_regex()]
end
