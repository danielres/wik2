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
