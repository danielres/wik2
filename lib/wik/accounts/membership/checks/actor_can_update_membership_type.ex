defmodule Wik.Accounts.Membership.Checks.ActorCanUpdateMembershipType do
  use Ash.Policy.SimpleCheck

  alias Wik.Accounts.Space.Checks.Access

  @impl true
  def describe(_opts), do: "actor can update another non-owner membership in a space they own"

  @impl true
  def match?(nil, _context, _opts), do: {:ok, false}

  def match?(actor, %{subject: subject}, _opts) do
    membership_type = Ash.Subject.get_argument_or_attribute(subject, :type, subject.data.type)

    membership_user_id =
      Ash.Subject.get_argument_or_attribute(subject, :user_id, subject.data.user_id)

    membership_space_id =
      Ash.Subject.get_argument_or_attribute(subject, :space_id, subject.data.space_id)

    cond do
      membership_type == :owner ->
        {:ok, false}

      membership_user_id == actor.id ->
        {:ok, false}

      true ->
        {:ok, membership_space_id in Access.membership_space_ids(actor.id, [:owner])}
    end
  end
end
