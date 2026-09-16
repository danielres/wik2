defmodule Wik.Library.Entry.Changes.NormalizeValues do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Ash.Query
  alias Wik.Library.EntryType
  alias WikWeb.LibraryLive.Schema

  require Ash.Query

  @impl true
  def change(changeset, _opts, context) do
    type_id = Changeset.get_attribute(changeset, :type_id)
    values = Changeset.get_attribute(changeset, :values) || %{}

    with {:ok, tenant} <- Ash.Scope.ToOpts.get_tenant(context),
         %EntryType{} = type <- load_type(type_id, tenant),
         {:ok, values} <- Schema.entry_values(type.fields, values) do
      Changeset.force_change_attribute(changeset, :values, values)
    else
      nil ->
        Changeset.add_error(changeset, field: :type_id, message: "is not available")

      {:error, errors} when is_list(errors) ->
        Enum.reduce(errors, changeset, fn message, changeset ->
          Changeset.add_error(changeset, field: :values, message: message)
        end)

      _error ->
        Changeset.add_error(changeset, field: :values, message: "could not be validated")
    end
  end

  defp load_type(type_id, tenant) do
    EntryType
    |> Query.filter(id == ^type_id)
    |> Query.load(:fields)
    |> Ash.read_one!(authorize?: false, domain: Wik.Library, tenant: tenant)
  end
end
