defmodule Wik.Activity.NotificationMapper do
  alias Ash.Notifier.Notification
  alias Wik.Accounts
  alias Wik.Accounts.Membership
  alias Wik.Accounts.Space
  alias Wik.Accounts.User
  alias Wik.Blocks.Block
  alias Wik.Blocks.BlockPlacement
  alias Wik.Events.Event
  alias Wik.Events.EventParticipation
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalEvent
  alias Wik.Tags.Tag
  alias Wik.Tags.Tagging
  alias Wik.Wiki.PageTree
  alias Wik.Wiki.PageTree.TreeQueries

  require Ash.Query

  def map(%Notification{action: %{name: action}, resource: resource} = notification) do
    case {resource, action} do
      {Space, :create} ->
        map_space(notification, :space_created)

      {Space, :update} ->
        map_space(notification, :space_updated)

      {Membership, :create} ->
        map_membership_created(notification)

      {Membership, :destroy} ->
        map_membership(notification, :member_left)

      {Membership, :set_primary_block} ->
        map_membership(notification, :member_profile_updated)

      {Membership, :set_username} ->
        map_membership(notification, :member_profile_updated)

      {Membership, :set_type} ->
        map_membership(notification, :member_role_changed)

      {Membership, :transfer_ownership} ->
        map_membership(notification, :member_role_changed)

      {Membership, :update_membership_type} ->
        map_membership(notification, :member_role_changed)

      {Tag, :create} ->
        map_tag(notification, :topic_created)

      {Tag, :destroy} ->
        map_tag(notification, :topic_deleted)

      {Tag, :set_primary_block} ->
        map_tag(notification, :topic_updated)

      {Tag, :update} ->
        map_tag(notification, :topic_updated)

      {Tagging, :create} ->
        map_tagging(notification, :member_tag_added)

      {Tagging, :destroy} ->
        map_tagging(notification, :member_tag_removed)

      {Tagging, :update_details} ->
        map_tagging(notification, :member_tag_updated)

      {Event, :create} ->
        map_event(notification, :event_created)

      {Event, :update} ->
        map_event_updated(notification)

      {EventPublication, :relay_to_space} ->
        map_event_relay(notification)

      {EventParticipation, :create} ->
        map_participation(notification, :event_participation_changed)

      {EventParticipation, :destroy} ->
        map_participation(notification, :event_participation_removed)

      {EventParticipation, :update_details} ->
        map_participation(notification, :event_participation_changed)

      {PageTree, action}
      when action in [:create_node_at_path, :destroy_node, :link_page, :move_node] ->
        map_page_tree(notification)

      {Block, :update} ->
        map_block(notification)

      {BlockPlacement, action} when action in [:create, :destroy, :update_area, :update_order] ->
        map_block_placement(notification)

      _other ->
        []
    end
  end

  defp map_space(notification, kind) do
    space = notification.data

    if kind == :space_updated and
         not changed_any?(notification, [:description, :name, :slug]) do
      []
    else
      [
        entry(notification, space.id, %{
          category: :other,
          collapse_key: if(kind == :space_updated, do: "space:#{space.id}"),
          collapsible?: kind == :space_updated,
          kind: kind,
          metadata: %{},
          subject_id: space.id,
          subject_label: space.name,
          subject_path: if(kind == :space_created, do: "/#{space.slug}"),
          subject_type: :space
        })
      ]
    end
  end

  defp map_membership_created(%{actor: nil, data: %{type: :owner}}), do: []
  defp map_membership_created(notification), do: map_membership(notification, :member_joined)

  defp map_membership(notification, kind) do
    membership = notification.data
    space = load_space(membership.space_id)
    membership = load_membership(membership.id, membership.space_id) || membership
    snapshot = membership_snapshot(membership)

    metadata =
      case kind do
        :member_role_changed -> %{role: membership.type}
        _other -> %{}
      end

    [
      entry(notification, membership.space_id, %{
        actor_membership: if(kind == :member_joined, do: membership),
        actor_snapshot: if(kind == :member_left, do: snapshot),
        category: :members,
        collapse_key: if(kind == :member_profile_updated, do: "member:#{membership.id}:profile"),
        collapsible?: kind == :member_profile_updated,
        kind: kind,
        metadata: metadata,
        subject_id: membership.id,
        subject_label: snapshot.label,
        subject_path: member_path(space, snapshot.username, kind),
        subject_type: :member
      })
    ]
  end

  defp map_tag(notification, kind) do
    tag = notification.data
    space = load_space(tag.space_id)
    target = %{id: tag.id, label: tag.name, path: topic_path(space, tag, kind)}

    [
      entry(
        notification,
        tag.space_id,
        Map.merge(
          %{
            category: :topics,
            kind: kind,
            subject_id: tag.id,
            subject_label: tag.name,
            subject_path: target.path,
            subject_type: :topic
          },
          consecutive_target_attrs(notification, kind, [target], "topic:#{tag.id}")
        )
      )
    ]
  end

  defp map_tagging(notification, kind) do
    tagging = notification.data

    if tagging.taggable_type == "membership" do
      with %Tag{} = tag <- load_tag(tagging.tag_id, tagging.space_id),
           %Membership{} = membership <- load_membership(tagging.taggable_id, tagging.space_id),
           %Space{} = space <- load_space(tagging.space_id) do
        snapshot = membership_snapshot(membership)

        [
          entry(notification, tagging.space_id, %{
            category: :members,
            collapse_key: if(kind == :member_tag_updated, do: "member_tag:#{tagging.id}"),
            collapsible?: kind == :member_tag_updated,
            kind: kind,
            metadata: %{
              description: tagging.description,
              tag_id: tag.id,
              tag_label: tag.name
            },
            subject_id: membership.id,
            subject_label: snapshot.label,
            subject_path: member_tag_path(space, snapshot.username, tag.slug, kind),
            subject_type: :member
          })
        ]
      else
        _missing -> []
      end
    else
      []
    end
  end

  defp map_event_updated(notification) do
    kind = if notification.data.status == :cancelled, do: :event_cancelled, else: :event_updated
    map_event(notification, kind)
  end

  defp map_event(notification, kind) do
    event = notification.data
    space = load_space(event.space_id)

    [
      entry(notification, event.space_id, %{
        category: :events,
        collapse_key: if(kind == :event_updated, do: "event:#{event.id}"),
        collapsible?: kind == :event_updated,
        kind: kind,
        metadata: %{},
        subject_id: event.id,
        subject_label: event.title,
        subject_path: event_path(space, event.id, :internal),
        subject_type: :event
      })
    ]
  end

  defp map_event_relay(notification) do
    publication = notification.data

    with %Event{} = event <- load_event(publication.event_id),
         %Space{} = space <- load_space(publication.target_space_id) do
      [
        entry(notification, publication.target_space_id, %{
          category: :events,
          kind: :event_relayed,
          metadata: %{relay_note: publication.relay_note},
          subject_id: event.id,
          subject_label: event.title,
          subject_path: event_path(space, event.id, :internal),
          subject_type: :event
        })
      ]
    else
      _missing -> []
    end
  end

  defp map_participation(notification, kind) do
    participation = notification.data

    with %Membership{} = membership <-
           load_membership(participation.membership_id, participation.space_id),
         %Space{} = space <- load_space(participation.space_id),
         {:ok, target} <- participation_target(participation, space) do
      metadata = %{
        interest_band:
          if(kind == :event_participation_removed,
            do: nil,
            else: interest_band(participation.interest)
          ),
        note: if(kind == :event_participation_removed, do: nil, else: participation.extra_info),
        source_type: target.source_type
      }

      [
        entry(notification, participation.space_id, %{
          actor_membership: membership,
          category: :events,
          collapse_key:
            "participation:#{participation.membership_id}:#{target.source_type}:#{target.id}",
          collapsible?: true,
          kind: kind,
          metadata: metadata,
          subject_id: target.id,
          subject_label: target.label,
          subject_path: target.path,
          subject_type: :event
        })
      ]
    else
      _missing -> []
    end
  end

  defp map_page_tree(notification) do
    page_tree = notification.data
    old_nodes = notification.changeset.data.nodes || []
    new_nodes = page_tree.nodes || []
    space = load_space(page_tree.space_id)

    old_pages = page_nodes(old_nodes)
    new_pages = page_nodes(new_nodes)

    added_ids = Map.keys(new_pages) -- Map.keys(old_pages)
    removed_ids = Map.keys(old_pages) -- Map.keys(new_pages)

    changed_ids =
      old_pages
      |> Map.keys()
      |> Enum.filter(&Map.has_key?(new_pages, &1))
      |> Enum.filter(fn page_id ->
        page_node_snapshot(old_nodes, Map.fetch!(old_pages, page_id)) !=
          page_node_snapshot(new_nodes, Map.fetch!(new_pages, page_id))
      end)

    created_entries =
      Enum.map(added_ids, fn page_id ->
        page_entry(notification, space, new_nodes, Map.fetch!(new_pages, page_id), :page_created)
      end)

    deleted_entries =
      Enum.map(removed_ids, fn page_id ->
        page_entry(notification, space, old_nodes, Map.fetch!(old_pages, page_id), :page_deleted)
      end)

    updated_entries =
      Enum.map(changed_ids, fn page_id ->
        page_entry(notification, space, new_nodes, Map.fetch!(new_pages, page_id), :page_updated)
      end)

    created_entries ++ deleted_entries ++ updated_entries
  end

  defp map_block(notification) do
    block = notification.data

    if changed_any?(notification, [:data, :type]) do
      block_page_entries(notification, block) ++
        block_topic_entries(notification, block) ++
        block_member_entries(notification, block)
    else
      []
    end
  end

  defp map_block_placement(notification) do
    placement = notification.data

    if placement.attachable_type == "page" do
      with %Space{} = space <- load_space(placement.space_id),
           %PageTree{} = page_tree <- load_page_tree(placement.space_id),
           node when not is_nil(node) <-
             Enum.find(page_tree.nodes, &(&1.page_id == placement.attachable_id)) do
        [page_entry(notification, space, page_tree.nodes, node, :page_updated)]
      else
        _missing -> []
      end
    else
      []
    end
  end

  defp block_page_entries(notification, block) do
    placements =
      BlockPlacement
      |> Ash.Query.filter(block_id == ^block.id and attachable_type == "page")
      |> Ash.read!(authorize?: false)

    placements
    |> Enum.group_by(& &1.space_id)
    |> Enum.flat_map(fn {space_id, space_placements} ->
      with %Space{} = space <- load_space(space_id),
           %PageTree{} = page_tree <- load_page_tree(space_id) do
        page_ids = MapSet.new(space_placements, & &1.attachable_id)

        targets =
          page_tree.nodes
          |> Enum.filter(&(&1.page_id && MapSet.member?(page_ids, &1.page_id)))
          |> Enum.map(&page_target(space, page_tree.nodes, &1))
          |> Enum.sort_by(& &1.path)

        case targets do
          [] ->
            []

          [primary | _rest] ->
            [
              entry(
                notification,
                space_id,
                Map.merge(
                  %{
                    category: :wiki,
                    kind: :page_updated,
                    subject_id: primary.id,
                    subject_label: primary.label,
                    subject_path: primary.path,
                    subject_type: :page
                  },
                  consecutive_target_attrs(
                    notification,
                    :page_updated,
                    targets,
                    page_targets_collapse_key(targets)
                  )
                )
              )
            ]
        end
      else
        _missing -> []
      end
    end)
  end

  defp block_topic_entries(notification, block) do
    if block.owner_space_id do
      Tag
      |> Ash.Query.filter(primary_block_id == ^block.id)
      |> Ash.read!(authorize?: false, tenant: block.owner_space_id)
      |> Enum.map(fn tag ->
        space = load_space(tag.space_id)
        target = %{id: tag.id, label: tag.name, path: topic_path(space, tag, :topic_updated)}

        entry(
          notification,
          tag.space_id,
          Map.merge(
            %{
              category: :topics,
              kind: :topic_updated,
              subject_id: tag.id,
              subject_label: tag.name,
              subject_path: target.path,
              subject_type: :topic
            },
            consecutive_target_attrs(notification, :topic_updated, [target], "topic:#{tag.id}")
          )
        )
      end)
    else
      []
    end
  end

  defp block_member_entries(notification, block) do
    Membership
    |> Ash.Query.filter(primary_block_id == ^block.id)
    |> Ash.read!(authorize?: false, load: [:space, user: [:external_identities]])
    |> Enum.map(fn membership ->
      snapshot = membership_snapshot(membership)

      entry(notification, membership.space_id, %{
        category: :members,
        collapse_key: "member:#{membership.id}:profile",
        collapsible?: true,
        kind: :member_profile_updated,
        metadata: %{},
        subject_id: membership.id,
        subject_label: snapshot.label,
        subject_path: member_path(membership.space, snapshot.username, :member_profile_updated),
        subject_type: :member
      })
    end)
  end

  defp page_entry(notification, space, nodes, node, kind) do
    target = page_target(space, nodes, node)
    target = if kind == :page_deleted, do: Map.put(target, :path, nil), else: target

    entry(
      notification,
      space.id,
      Map.merge(
        %{
          category: :wiki,
          kind: kind,
          subject_id: target.id,
          subject_label: target.label,
          subject_path: target.path,
          subject_type: :page
        },
        consecutive_target_attrs(notification, kind, [target], "page:#{target.id}")
      )
    )
  end

  defp page_target(space, nodes, node) do
    %{
      id: node.page_id,
      label: TreeQueries.get_node_title_path(nodes, node.id),
      path: "/#{space.slug}/wiki/#{TreeQueries.get_node_path(nodes, node.id)}"
    }
  end

  defp page_nodes(nodes) do
    nodes
    |> Enum.reject(&is_nil(&1.page_id))
    |> Map.new(&{&1.page_id, &1})
  end

  defp page_node_snapshot(nodes, node) do
    {TreeQueries.get_node_path(nodes, node.id), TreeQueries.get_node_title_path(nodes, node.id)}
  end

  defp participation_target(%{publication_id: publication_id}, space)
       when not is_nil(publication_id) do
    with %EventPublication{} = publication <- load_publication(publication_id, space.id),
         %Event{} = event <- load_event(publication.event_id) do
      {:ok,
       %{
         id: event.id,
         label: event.title,
         path: event_path(space, event.id, :internal),
         source_type: :internal
       }}
    else
      _missing -> {:error, :not_found}
    end
  end

  defp participation_target(%{external_event_id: external_event_id}, space)
       when not is_nil(external_event_id) do
    case load_external_event(external_event_id, space.id) do
      %ExternalEvent{} = event ->
        {:ok,
         %{
           id: event.id,
           label: event.title,
           path: event_path(space, event.id, :external),
           source_type: :external
         }}

      nil ->
        {:error, :not_found}
    end
  end

  defp entry(notification, space_id, attrs) do
    attrs =
      Map.update!(attrs, :subject_label, &subject_label(&1, Map.fetch!(attrs, :subject_type)))

    actor_membership =
      if Map.has_key?(attrs, :actor_membership) do
        Map.get(attrs, :actor_membership)
      else
        actor_membership(notification, space_id)
      end

    actor = Map.get(attrs, :actor_snapshot) || actor_snapshot(notification, actor_membership)

    attrs
    |> Map.delete(:actor_membership)
    |> Map.delete(:actor_snapshot)
    |> Map.merge(%{
      actor_label: actor.label,
      actor_membership_id: actor_membership && actor_membership.id,
      actor_username: actor.username,
      space_id: space_id
    })
  end

  defp consecutive_target_attrs(
         %Notification{actor: %User{id: actor_id}},
         kind,
         targets,
         _fallback_key
       )
       when is_binary(actor_id) do
    %{
      collapse_key: "consecutive:#{kind}:#{actor_id}",
      collapse_mode: :consecutive_targets,
      collapsible?: true,
      metadata: %{targets: targets}
    }
  end

  defp consecutive_target_attrs(_notification, kind, targets, fallback_key) do
    %{
      collapse_key: if(kind in [:page_updated, :topic_updated], do: fallback_key),
      collapsible?: kind in [:page_updated, :topic_updated],
      metadata: %{targets: targets}
    }
  end

  defp page_targets_collapse_key([target]), do: "page:#{target.id}"

  defp page_targets_collapse_key(targets) do
    target_hash =
      targets
      |> Enum.map(& &1.id)
      |> Enum.sort()
      |> Enum.join(":")
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    "pages:#{target_hash}"
  end

  defp actor_membership(%{actor: %User{id: user_id}}, space_id) do
    case Accounts.get_membership(space_id, user_id) do
      {:ok, membership} -> membership
      {:error, _error} -> nil
    end
  end

  defp actor_membership(_notification, _space_id), do: nil

  defp actor_snapshot(_notification, %Membership{} = membership),
    do: membership_snapshot(membership)

  defp actor_snapshot(%{actor: %User{role: :superadmin}}, nil),
    do: %{id: nil, label: "Superadmin", username: nil}

  defp actor_snapshot(_notification, nil), do: membership_snapshot(nil)

  defp subject_label(label, _subject_type) when is_binary(label) and label != "", do: label
  defp subject_label(_label, :event), do: "Untitled event"
  defp subject_label(_label, :member), do: "Member"
  defp subject_label(_label, :page), do: "Untitled page"
  defp subject_label(_label, :space), do: "Space"
  defp subject_label(_label, :topic), do: "Topic"

  defp membership_snapshot(nil), do: %{id: nil, label: nil, username: nil}

  defp membership_snapshot(%Membership{} = membership) do
    presented = Accounts.present_membership(membership)

    %{
      id: membership.id,
      label:
        presented.display_name || membership.username || user_label(membership.user_id) ||
          "Member",
      username: membership.username
    }
  end

  defp user_label(user_id) do
    case Ash.get(User, user_id, authorize?: false) do
      {:ok, user} -> to_string(user)
      {:error, _error} -> nil
    end
  end

  defp load_membership(id, space_id) do
    Membership
    |> Ash.Query.filter(id == ^id and space_id == ^space_id)
    |> Ash.Query.load([:space, :avatar_url, user: [:external_identities]])
    |> Ash.read_one!(authorize?: false)
  end

  defp load_space(id) do
    case Ash.get(Space, id, authorize?: false) do
      {:ok, space} -> space
      {:error, _error} -> nil
    end
  end

  defp load_tag(id, space_id) do
    case Ash.get(Tag, id, authorize?: false, tenant: space_id) do
      {:ok, tag} -> tag
      {:error, _error} -> nil
    end
  end

  defp load_event(id) do
    case Ash.get(Event, id, authorize?: false) do
      {:ok, event} -> event
      {:error, _error} -> nil
    end
  end

  defp load_publication(id, space_id) do
    case Ash.get(EventPublication, id, authorize?: false, tenant: space_id) do
      {:ok, publication} -> publication
      {:error, _error} -> nil
    end
  end

  defp load_external_event(id, space_id) do
    case Ash.get(ExternalEvent, id, authorize?: false, tenant: space_id) do
      {:ok, event} -> event
      {:error, _error} -> nil
    end
  end

  defp load_page_tree(space_id) do
    PageTree
    |> Ash.Query.filter(space_id == ^space_id)
    |> Ash.read_one!(authorize?: false, tenant: space_id)
  end

  defp changed_any?(notification, attributes) do
    Enum.any?(attributes, &Map.has_key?(notification.changeset.attributes, &1))
  end

  defp interest_band(interest) when interest in 1..3, do: :considering
  defp interest_band(interest) when interest in 4..7, do: :likely
  defp interest_band(interest) when interest in 8..10, do: :planning
  defp interest_band(_interest), do: nil

  defp member_path(_space, _username, :member_left), do: nil

  defp member_path(%Space{slug: slug}, username, _kind)
       when is_binary(username) and username != "",
       do: "/#{slug}/wiki/members/#{username}"

  defp member_path(_space, _username, _kind), do: nil

  defp member_tag_path(_space, _username, _tag_slug, :member_tag_removed), do: nil

  defp member_tag_path(%Space{slug: space_slug}, username, tag_slug, _kind)
       when is_binary(username) and username != "",
       do: "/#{space_slug}/wiki/members/#{username}/tag/#{tag_slug}"

  defp member_tag_path(_space, _username, _tag_slug, _kind), do: nil

  defp topic_path(_space, _tag, :topic_deleted), do: nil
  defp topic_path(%Space{slug: space_slug}, tag, _kind), do: "/#{space_slug}/topics/#{tag.slug}"

  defp event_path(%Space{slug: slug}, event_id, :internal),
    do: "/#{slug}/events?event=#{event_id}"

  defp event_path(%Space{slug: slug}, event_id, :external),
    do: "/#{slug}/events?ext=#{event_id}"
end
