defmodule Wik.Accounts.Group.Changes.CreateWithOwnerMembership do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Ash.Error.Changes.InvalidRelationship
  alias Wik.Accounts.GroupUserRelation

  @impl true
  def change(changeset, _opts, %{actor: actor}) do
    case actor do
      nil ->
        Changeset.add_error(
          changeset,
          InvalidRelationship.exception(
            relationship: :author,
            message: "could not relate to actor, as no actor was found"
          )
        )

      actor ->
        changeset
        |> Changeset.manage_relationship(:author, actor,
          type: :append_and_remove,
          authorize?: false
        )
        |> Changeset.after_action(fn _changeset, group ->
          case Ash.create(
                 GroupUserRelation,
                 %{
                   group_id: group.id,
                   type: :owner,
                   user_id: actor.id
                 },
                 authorize?: false,
                 domain: Wik.Accounts
               ) do
            {:ok, _membership} ->
              {:ok, group}

            {:error, error} ->
              {:error, error}
          end
        end)
    end
  end
end
