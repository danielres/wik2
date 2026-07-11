defmodule Wik.Tags.Tagging.Checks.ActorCanManageTagging do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts
  alias Wik.Accounts.Membership
  alias Wik.Scope
  alias Wik.Wiki.Page

  require Ash.Query

  @impl true
  def describe(_opts), do: "actor can manage the tagging target"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject} = context, _opts) do
    {:ok, tenant} = Ash.Scope.ToOpts.get_tenant(context)
    scope = %Scope{actor: actor, tenant: tenant}
    space_id = Accounts.tenant_to_space_id(tenant)
    taggable_type = Ash.Subject.get_argument_or_attribute(subject, :taggable_type)
    taggable_id = Ash.Subject.get_argument_or_attribute(subject, :taggable_id)
    author_id = Ash.Subject.get_argument_or_attribute(subject, :tagged_by_membership_id)

    with {:ok, true} <- actor_owns_membership?(actor, space_id, author_id) do
      actor_can_manage_target?(scope, space_id, taggable_type, taggable_id, author_id)
    end
  end

  defp actor_owns_membership?(_actor, _space_id, nil), do: {:ok, false}

  defp actor_owns_membership?(actor, space_id, membership_id) do
    Membership
    |> Ash.Query.filter(space_id == ^space_id and id == ^membership_id and user_id == ^actor.id)
    |> Ash.exists(authorize?: false, domain: Accounts)
  end

  defp actor_can_manage_target?(_scope, _space_id, "membership", membership_id, author_id),
    do: {:ok, membership_id == author_id}

  defp actor_can_manage_target?(scope, space_id, "page", page_id, _author_id) do
    Page
    |> Ash.Query.filter(space_id == ^space_id and id == ^page_id)
    |> Ash.read_one(authorize?: false, domain: Wik.Wiki, tenant: space_id)
    |> case do
      {:ok, nil} -> {:ok, false}
      {:ok, %Page{} = page} -> {:ok, Ash.can?({page, :manage_page}, scope)}
      {:error, error} -> {:error, error}
    end
  end

  defp actor_can_manage_target?(_scope, _space_id, _taggable_type, _taggable_id, _author_id),
    do: {:ok, false}
end
