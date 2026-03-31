defmodule Qblog.Repo.Migrations.MigrateResources4 do
  @moduledoc """
  Updates resources based on their most recent snapshots.
  """

  use Ecto.Migration

  def up do
    rename table(:groups), :owner_id, to: :author_id

    execute(
      "ALTER TABLE groups RENAME CONSTRAINT groups_owner_id_fkey TO groups_author_id_fkey",
      "ALTER TABLE groups RENAME CONSTRAINT groups_author_id_fkey TO groups_owner_id_fkey"
    )
  end

  def down do
    rename table(:groups), :author_id, to: :owner_id

    execute(
      "ALTER TABLE groups RENAME CONSTRAINT groups_author_id_fkey TO groups_owner_id_fkey",
      "ALTER TABLE groups RENAME CONSTRAINT groups_owner_id_fkey TO groups_author_id_fkey"
    )
  end
end
