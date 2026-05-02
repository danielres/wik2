# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Qblog.Repo.insert!(%Qblog.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Ash.Query
alias Qblog.Accounts
alias Qblog.Accounts.Group
alias Qblog.Accounts.GroupUserRelation
alias Qblog.Accounts.User
alias Qblog.Access
alias Qblog.Access.ExternalIdentity
alias Qblog.Access.Grant
alias Qblog.Access.Source

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

group =
  case Group
       |> Query.filter(name == "seed-group-two-members")
       |> Ash.read_one(authorize?: false, domain: Accounts) do
    {:ok, %Group{} = group} ->
      group

    {:ok, nil} ->
      Ash.create!(
        Group,
        %{
          description: "Seed group with two members",
          name: "seed-group-two-members"
        },
        action: :create,
        actor: owner,
        authorize?: false,
        domain: Accounts
      )
  end

case GroupUserRelation
     |> Query.filter(group_id == ^group.id and user_id == ^member.id)
     |> Ash.read_one(authorize?: false, domain: Accounts) do
  {:ok, %GroupUserRelation{}} ->
    :ok

  {:ok, nil} ->
    Ash.create!(
      GroupUserRelation,
      %{
        group_id: group.id,
        type: :member,
        user_id: member.id
      },
      authorize?: false,
      domain: Accounts
    )
end

source =
  case Source
       |> Query.filter(
         provider == :telegram and provider_source_id == "seed-group-two-members-chat"
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
          group_id: group.id,
          metadata: %{"kind" => "telegram_chat"},
          provider: :telegram,
          provider_source_id: "seed-group-two-members-chat",
          status: :active,
          title: "Seed Group Two Members"
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
