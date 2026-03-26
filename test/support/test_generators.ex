defmodule Qblog.TestGenerators do
  use Ash.Generator

  alias Qblog.Accounts.Group
  alias Qblog.Accounts.User
  alias Qblog.Wiki.PageTree

  def user(opts \\ []) do
    seed_generator(
      {User,
       %{
         email: sequence(:user_email, &"user-#{System.unique_integer([:positive])}-#{&1}@example.com"),
         role: :user
       }},
      overrides: opts
    )
  end

  def group(opts \\ []) do
    owner = Keyword.get(opts, :owner, user())

    seed_generator(
      fn %{owner: owner} ->
        owner = generate(owner)

        %Group{
           owner_id: owner.id,
           name: sequence(:group_name, &"group-#{System.unique_integer([:positive])}-#{&1}")
         }
      end,
      uses: [owner: owner],
      overrides: Keyword.drop(opts, [:owner])
    )
  end

  def page_tree(opts \\ []) do
    group = Keyword.get(opts, :group, group())

    seed_generator(
      fn %{group: group} ->
        group = generate(group)

        %PageTree{group_id: group.id, nodes: []}
      end,
      uses: [group: group],
      overrides: Keyword.drop(opts, [:group])
    )
  end
end
