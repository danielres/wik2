defmodule Wik.Repo.Migrations.RemoveObanTables do
  use Ecto.Migration

  def up do
    drop_if_exists table(:oban_peers)
    drop_if_exists table(:oban_jobs)

    execute "DROP FUNCTION IF EXISTS public.oban_jobs_notify()"
  end

  def down do
    raise Ecto.MigrationError, "Oban tables were removed after removing the Oban dependency"
  end
end
