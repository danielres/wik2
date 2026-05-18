defmodule Wik.TestGenerators do
  use Ash.Generator

  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source
  alias Wik.Accounts.Group
  alias Wik.Accounts.User
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge
  alias Wik.Wiki.PageTree

  def user(opts \\ []) do
    seed_generator(
      {User,
       %{
         email:
           sequence(:user_email, &"user-#{System.unique_integer([:positive])}-#{&1}@example.com"),
         role: :user
       }},
      overrides: opts
    )
  end

  def group(opts \\ []) do
    author = Keyword.get(opts, :author, user())

    seed_generator(
      fn %{author: author} ->
        author = generate(author)
        slug = sequence(:group_slug, &"group-#{System.unique_integer([:positive])}-#{&1}")

        %Group{
          author_id: author.id,
          name: slug,
          slug: slug
        }
      end,
      uses: [author: author],
      overrides: Keyword.drop(opts, [:author])
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

  def tag(opts \\ []) do
    group = Keyword.get(opts, :group, group())

    seed_generator(
      fn %{group: group} ->
        group = generate(group)
        slug = sequence(:tag_slug, &"tag-#{System.unique_integer([:positive])}-#{&1}")

        %Tag{
          group_id: group.id,
          name: slug,
          slug: slug
        }
      end,
      uses: [group: group],
      overrides: Keyword.drop(opts, [:group])
    )
  end

  def tag_edge(opts \\ []) do
    group = Keyword.get(opts, :group, group())
    parent_tag = Keyword.get(opts, :parent_tag, tag(group: group))
    child_tag = Keyword.get(opts, :child_tag, tag(group: group))

    seed_generator(
      fn %{group: group, parent_tag: parent_tag, child_tag: child_tag} ->
        group = generate(group)
        parent_tag = generate(parent_tag)
        child_tag = generate(child_tag)

        %TagEdge{
          group_id: group.id,
          parent_tag_id: parent_tag.id,
          child_tag_id: child_tag.id
        }
      end,
      uses: [group: group, parent_tag: parent_tag, child_tag: child_tag],
      overrides: Keyword.drop(opts, [:group, :parent_tag, :child_tag])
    )
  end

  def grant_active_telegram_access(group, user) do
    source =
      Ash.create!(
        Source,
        %{
          claimed_at: DateTime.utc_now(),
          claimed_by_user_id: user.id,
          group_id: group.id,
          provider: :telegram,
          provider_source_id: "telegram-source-#{System.unique_integer([:positive])}",
          status: :active,
          title: "Telegram Group"
        },
        authorize?: false,
        domain: Wik.Access
      )

    identity =
      Ash.create!(
        ExternalIdentity,
        %{
          display_name: "Telegram User",
          provider: :telegram,
          provider_user_id: "telegram-user-#{System.unique_integer([:positive])}",
          user_id: user.id
        },
        authorize?: false,
        domain: Wik.Access
      )

    grant =
      Ash.create!(
        Grant,
        %{
          external_identity_id: identity.id,
          last_verified_at: DateTime.utc_now(),
          source_id: source.id,
          status: :active,
          user_id: user.id
        },
        authorize?: false,
        domain: Wik.Access
      )

    %{grant: grant, identity: identity, source: source}
  end
end
