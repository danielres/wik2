defmodule Wik.TestGenerators do
  use Ash.Generator

  alias Wik.Access.ExternalIdentity
  alias Wik.Access.Grant
  alias Wik.Access.Source
  alias Wik.Accounts.Space
  alias Wik.Accounts.Membership
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

  def space(opts \\ []) do
    author = Keyword.get(opts, :author, user())

    seed_generator(
      fn %{author: author} ->
        author = generate(author)
        slug = sequence(:space_slug, &"space-#{System.unique_integer([:positive])}-#{&1}")

        %Space{
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
    space = Keyword.get(opts, :space, space())

    seed_generator(
      fn %{space: space} ->
        space = generate(space)

        %PageTree{space_id: space.id, nodes: []}
      end,
      uses: [space: space],
      overrides: Keyword.drop(opts, [:space])
    )
  end

  def tag(opts \\ []) do
    space = Keyword.get(opts, :space, space())

    seed_generator(
      fn %{space: space} ->
        space = generate(space)
        slug = sequence(:tag_slug, &"tag-#{System.unique_integer([:positive])}-#{&1}")

        %Tag{
          space_id: space.id,
          name: slug,
          slug: slug
        }
      end,
      uses: [space: space],
      overrides: Keyword.drop(opts, [:space])
    )
  end

  def membership(opts \\ []) do
    space = Keyword.get(opts, :space, space())
    user = Keyword.get(opts, :user, user())
    type = Keyword.get(opts, :type, :member)

    seed_generator(
      fn %{space: space, type: type, user: user} ->
        space = generate(space)
        user = generate(user)

        %Membership{
          space_id: space.id,
          type: type,
          user_id: user.id
        }
      end,
      uses: [space: space, type: type, user: user],
      overrides: Keyword.drop(opts, [:space, :type, :user])
    )
  end

  def tag_edge(opts \\ []) do
    space = Keyword.get(opts, :space, space())
    parent_tag = Keyword.get(opts, :parent_tag)
    child_tag = Keyword.get(opts, :child_tag)

    seed_generator(
      fn %{space: space, parent_tag: parent_tag, child_tag: child_tag} ->
        space = generate(space)

        parent_tag =
          case parent_tag do
            nil -> generate(tag(space: space))
            value -> generate(value)
          end

        child_tag =
          case child_tag do
            nil -> generate(tag(space: space))
            value -> generate(value)
          end

        %TagEdge{
          space_id: space.id,
          parent_tag_id: parent_tag.id,
          child_tag_id: child_tag.id
        }
      end,
      uses: [space: space, parent_tag: parent_tag, child_tag: child_tag],
      overrides: Keyword.drop(opts, [:space, :parent_tag, :child_tag])
    )
  end

  def tagging(opts \\ []) do
    space = Keyword.get(opts, :space, space())
    membership_seed = Keyword.get(opts, :membership)
    tag_seed = Keyword.get(opts, :tag)
    dimensions = Keyword.get(opts, :dimensions, %{"interest" => 3})
    description = Keyword.get(opts, :description)

    seed_generator(
      fn %{
           description: description,
           dimensions: dimensions,
           space: space,
           membership_seed: membership_seed,
           tag_seed: tag_seed
         } ->
        space = generate(space)

        membership =
          case membership_seed do
            nil -> generate(membership(space: space))
            value -> generate(value)
          end

        tag =
          case tag_seed do
            nil -> generate(tag(space: space))
            value -> generate(value)
          end

        %Tagging{
          description: description,
          dimensions: dimensions,
          space_id: space.id,
          tag_id: tag.id,
          tagged_by_membership_id: membership.id,
          taggable_id: membership.id,
          taggable_type: "membership"
        }
      end,
      uses: [
        description: description,
        dimensions: dimensions,
        space: space,
        membership_seed: membership_seed,
        tag_seed: tag_seed
      ],
      overrides: Keyword.drop(opts, [:description, :dimensions, :space, :membership, :tag])
    )
  end

  def grant_active_telegram_access(space, user) do
    source =
      Ash.create!(
        Source,
        %{
          claimed_at: DateTime.utc_now(),
          claimed_by_user_id: user.id,
          space_id: space.id,
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
