defmodule Wik.Tags.Tagging.Checks.ActorCanManageOwnMembershipTagging do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.GroupUserRelation

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor owns the membership tagging they are managing"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    group_id = Accounts.tenant_to_group_id(tenant)
    taggable_type = Ash.Subject.get_argument_or_attribute(subject, :taggable_type)
    taggable_id = Ash.Subject.get_argument_or_attribute(subject, :taggable_id)
    author_id = Ash.Subject.get_argument_or_attribute(subject, :tagged_by_group_user_relation_id)

    if taggable_type == "group_user_relation" and taggable_id == author_id do
      GroupUserRelation
      |> Ash.Query.filter(group_id == ^group_id and id == ^author_id and user_id == ^actor.id)
      |> Ash.exists(authorize?: false, domain: Accounts)
    else
      {:ok, false}
    end
  end
end
