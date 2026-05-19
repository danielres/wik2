defmodule Wik.TestGenerators do
  use Ash.Generator

  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source
  alias Wik.Accounts.Group
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Accounts.User
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge
  alias Wik.Tags.Tagging
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

  def membership(opts \\ []) do
    group = Keyword.get(opts, :group, group())
    user = Keyword.get(opts, :user, user())
    type = Keyword.get(opts, :type, :member)

    seed_generator(
      fn %{group: group, type: type, user: user} ->
        group = generate(group)
        user = generate(user)

        %GroupUserRelation{
          group_id: group.id,
          type: type,
          user_id: user.id
        }
      end,
      uses: [group: group, type: type, user: user],
      overrides: Keyword.drop(opts, [:group, :type, :user])
    )
  end

  def tag_edge(opts \\ []) do
    group = Keyword.get(opts, :group, group())
    parent_tag = Keyword.get(opts, :parent_tag)
    child_tag = Keyword.get(opts, :child_tag)

    seed_generator(
      fn %{group: group, parent_tag: parent_tag, child_tag: child_tag} ->
        group = generate(group)

        parent_tag =
          case parent_tag do
            nil -> generate(tag(group: group))
            value -> generate(value)
          end

        child_tag =
          case child_tag do
            nil -> generate(tag(group: group))
            value -> generate(value)
          end

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

  def tagging(opts \\ []) do
    group = Keyword.get(opts, :group, group())
    membership_seed = Keyword.get(opts, :membership)
    tag_seed = Keyword.get(opts, :tag)
    dimensions = Keyword.get(opts, :dimensions, %{"interest" => 3})
    description = Keyword.get(opts, :description)

    seed_generator(
      fn %{
           description: description,
           dimensions: dimensions,
           group: group,
           membership_seed: membership_seed,
           tag_seed: tag_seed
         } ->
        group = generate(group)

        membership =
          case membership_seed do
            nil -> generate(membership(group: group))
            value -> generate(value)
          end

        tag =
          case tag_seed do
            nil -> generate(tag(group: group))
            value -> generate(value)
          end

        %Tagging{
          description: description,
          dimensions: dimensions,
          group_id: group.id,
          tag_id: tag.id,
          tagged_by_group_user_relation_id: membership.id,
          taggable_id: membership.id,
          taggable_type: "group_user_relation"
        }
      end,
      uses: [
        description: description,
        dimensions: dimensions,
        group: group,
        membership_seed: membership_seed,
        tag_seed: tag_seed
      ],
      overrides: Keyword.drop(opts, [:description, :dimensions, :group, :membership, :tag])
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
