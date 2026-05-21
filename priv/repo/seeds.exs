# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Wik.Repo.insert!(%Wik.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Ash.Query
alias Wik.Accounts
alias Wik.Accounts.Space
alias Wik.Accounts.Membership
alias Wik.Accounts.User
alias Wik.Access
alias Wik.Access.ExternalIdentity
alias Wik.Access.Grant
alias Wik.Access.Source

require Ash.Query

owner =
  case User
       |> Query.filter(email == "seed-owner@example.com")
       |> Ash.read_one(authorize?: false, domain: Accounts) do
    {:ok, %User{} = user} ->
      user

    {:ok, nil} ->
      Ash.create!(
        User,
        %{email: "seed-owner@example.com", role: :user},
        action: :create_dev_user,
        authorize?: false,
        domain: Accounts
      )
  end

member =
  case User
       |> Query.filter(email == "seed-member@example.com")
       |> Ash.read_one(authorize?: false, domain: Accounts) do
    {:ok, %User{} = user} ->
      user

    {:ok, nil} ->
      Ash.create!(
        User,
        %{email: "seed-member@example.com", role: :user},
        action: :create_dev_user,
        authorize?: false,
        domain: Accounts
      )
  end

space =
  case Space
       |> Query.filter(name == "Seed Space 2 members")
       |> Ash.read_one(authorize?: false, domain: Accounts) do
    {:ok, %Space{} = space} ->
      space

    {:ok, nil} ->
      Ash.create!(
        Space,
        %{
          description: "Seed space with two members",
          name: "Seed Space 2 members",
          slug: "seed-space-2-members"
        },
        action: :create,
        actor: owner,
        authorize?: false,
        domain: Accounts
      )
  end

owner_membership =
  case Membership
       |> Query.filter(space_id == ^space.id and user_id == ^owner.id)
       |> Ash.read_one(authorize?: false, domain: Accounts) do
    {:ok, %Membership{} = membership} ->
      membership

    {:ok, nil} ->
      raise "Expected owner membership to exist for seeded space"
  end

member_membership =
  case Membership
       |> Query.filter(space_id == ^space.id and user_id == ^member.id)
       |> Ash.read_one(authorize?: false, domain: Accounts) do
    {:ok, %Membership{} = membership} ->
      membership

    {:ok, nil} ->
      Ash.create!(
        Membership,
        %{
          space_id: space.id,
          type: :member,
          user_id: member.id
        },
        authorize?: false,
        domain: Accounts
      )
  end

for {membership, username} <- [
      {owner_membership, "owner"},
      {member_membership, "member"}
    ] do
  if membership.username != username do
    Ash.update!(
      membership,
      %{username: username},
      action: :set_username,
      authorize?: false,
      domain: Accounts
    )
  end
end

source =
  case Source
       |> Query.filter(
         provider == :telegram and provider_source_id == "seed-space-two-members-chat"
       )
       |> Ash.read_one(authorize?: false, domain: Access) do
    {:ok, %Source{} = source} ->
      source

    {:ok, nil} ->
      Ash.create!(
        Source,
        %{
          claimed_at: DateTime.utc_now(),
          claimed_by_user_id: owner.id,
          space_id: space.id,
          metadata: %{"kind" => "telegram_chat"},
          provider: :telegram,
          provider_source_id: "seed-space-two-members-chat",
          status: :active,
          title: "Seed Space Two Members"
        },
        authorize?: false,
        domain: Access
      )
  end

identity =
  case ExternalIdentity
       |> Query.filter(provider == :telegram and provider_user_id == "seed-member-telegram")
       |> Ash.read_one(authorize?: false, domain: Access) do
    {:ok, %ExternalIdentity{} = identity} ->
      identity

    {:ok, nil} ->
      Ash.create!(
        ExternalIdentity,
        %{
          display_name: "Seed Member",
          metadata: %{},
          provider: :telegram,
          provider_user_id: "seed-member-telegram",
          user_id: member.id,
          username: "seed_member"
        },
        authorize?: false,
        domain: Access
      )
  end

case Grant
     |> Query.filter(source_id == ^source.id and user_id == ^member.id)
     |> Ash.read_one(authorize?: false, domain: Access) do
  {:ok, %Grant{}} ->
    :ok

  {:ok, nil} ->
    Ash.create!(
      Grant,
      %{
        external_identity_id: identity.id,
        last_verified_at: DateTime.utc_now(),
        source_id: source.id,
        status: :active,
        user_id: member.id
      },
      authorize?: false,
      domain: Access
    )
end

many_members_space =
  case Space
       |> Query.filter(name == "Seed Space 25 members")
       |> Ash.read_one(authorize?: false, domain: Accounts) do
    {:ok, %Space{} = space} ->
      space

    {:ok, nil} ->
      Ash.create!(
        Space,
        %{
          description: "Seed space with twenty-five members",
          name: "Seed Space 25 members",
          slug: "seed-space-25-members"
        },
        action: :create,
        actor: owner,
        authorize?: false,
        domain: Accounts
      )
  end

many_members_owner_membership =
  case Membership
       |> Query.filter(space_id == ^many_members_space.id and user_id == ^owner.id)
       |> Ash.read_one(authorize?: false, domain: Accounts) do
    {:ok, %Membership{} = membership} ->
      membership

    {:ok, nil} ->
      raise "Expected owner membership to exist for 25-member seeded space"
  end

if many_members_owner_membership.username != "owner" do
  Ash.update!(
    many_members_owner_membership,
    %{username: "owner"},
    action: :set_username,
    authorize?: false,
    domain: Accounts
  )
end

for index <- 1..25 do
  username = "m#{index}"
  email = "seed-#{username}@example.com"

  user =
    case User
         |> Query.filter(email == ^email)
         |> Ash.read_one(authorize?: false, domain: Accounts) do
      {:ok, %User{} = user} ->
        user

      {:ok, nil} ->
        Ash.create!(
          User,
          %{email: email, role: :user},
          action: :create_dev_user,
          authorize?: false,
          domain: Accounts
        )
    end

  membership =
    case Membership
         |> Query.filter(space_id == ^many_members_space.id and user_id == ^user.id)
         |> Ash.read_one(authorize?: false, domain: Accounts) do
      {:ok, %Membership{} = membership} ->
        membership

      {:ok, nil} ->
        Ash.create!(
          Membership,
          %{
            space_id: many_members_space.id,
            type: :member,
            user_id: user.id
          },
          authorize?: false,
          domain: Accounts
        )
    end

  if membership.username != username do
    Ash.update!(
      membership,
      %{username: username},
      action: :set_username,
      authorize?: false,
      domain: Accounts
    )
  end
end
