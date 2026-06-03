defmodule Wik.EventParticipationsTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Ash.Query
  alias Wik.Accounts.Membership
  alias Wik.Events
  alias Wik.Events.Event
  alias Wik.Events.EventParticipation
  alias Wik.Events.EventPublication
  alias Wik.Events.ExternalCalendarSubscription
  alias Wik.Events.ExternalEvent
  alias Wik.Repo
  alias Wik.Scope

  describe "record_interest/3" do
    test "upserts one interest record per publication and member" do
      %{
        member: member,
        membership: membership,
        owner: owner,
        publication: publication,
        space: space
      } =
        internal_event_fixture()

      assert {:ok, first} =
               Events.record_interest(
                 publication,
                 %{"extra_info" => "joining around 15:00", "interest" => "7"},
                 scope: scope(member, space)
               )

      assert {:ok, second} =
               Events.record_interest(
                 publication,
                 %{extra_info: "", interest: 9},
                 scope: scope(member, space)
               )

      assert first.id == second.id

      assert {:ok, [participation]} =
               EventParticipation
               |> Query.filter(publication_id == ^publication.id)
               |> Ash.read(scope: scope(owner, space))

      assert participation.membership_id == membership.id
      assert participation.interest == 9
      assert participation.extra_info == nil
    end
  end

  describe "record_external_interest/3" do
    test "creates and reuses one converted event for an external occurrence" do
      owner = generate(user())
      member = generate(user())
      other_member = generate(user())
      space = generate(space(author: owner))
      add_membership(space, owner, :owner)
      add_membership(space, member, :member)
      add_membership(space, other_member, :member)

      external_event = external_event_fixture(space, owner)

      assert {:ok, first} =
               Events.record_external_interest(
                 external_event,
                 %{interest: 8, extra_info: "picnic after work"},
                 scope: scope(member, space)
               )

      assert {:ok, second} =
               Events.record_external_interest(
                 external_event,
                 %{interest: 4, extra_info: nil},
                 scope: scope(other_member, space)
               )

      assert first.publication.event_id == second.publication.event_id

      assert {:ok, event} =
               Event
               |> Query.filter(source_external_event_id == ^external_event.id)
               |> Ash.read_one(scope: scope(owner, space))

      assert event.author_id == member.id
      assert event.title == nil
      assert event.source_external_event_id == external_event.id

      assert {:ok, participations} =
               EventParticipation
               |> Query.filter(publication_id == ^first.publication.id)
               |> Ash.read(scope: scope(owner, space))

      assert Enum.sort(Enum.map(participations, & &1.interest)) == [4, 8]
    end
  end

  defp internal_event_fixture do
    owner = generate(user())
    member = generate(user())
    space = generate(space(author: owner))
    add_membership(space, owner, :owner)
    membership = add_membership(space, member, :member)

    {:ok, event} =
      Ash.create(Event, event_attrs(), action: :create, scope: scope(owner, space))

    {:ok, publication} =
      EventPublication
      |> Query.filter(event_id == ^event.id and target_space_id == ^space.id)
      |> Ash.read_one(scope: scope(owner, space))

    %{
      member: member,
      membership: membership,
      owner: owner,
      publication: publication,
      space: space
    }
  end

  defp external_event_fixture(space, owner) do
    {:ok, subscription} =
      ExternalCalendarSubscription.create(
        %{ics_url: "https://calendar.example.test/community.ics"},
        scope: scope(owner, space)
      )

    Repo.insert!(%ExternalEvent{
      all_day: false,
      calendar_name: "Community calendar",
      description: "Imported from an external calendar",
      ends_at: ~U[2026-06-03 20:00:00Z],
      event_url: nil,
      external_occurrence_key: "single",
      external_recurrence_id: nil,
      external_uid: "external-dinner",
      last_seen_at: DateTime.utc_now(),
      location: "Riverside Hall",
      space_id: space.id,
      starts_at: ~U[2026-06-03 18:00:00Z],
      status: :published,
      subscription_id: subscription.id,
      title: "External dinner",
      tz: "Etc/UTC"
    })
  end

  defp add_membership(space, user, type) do
    Ash.create!(
      Membership,
      %{space_id: space.id, type: type, user_id: user.id},
      authorize?: false,
      domain: Wik.Accounts
    )
  end

  defp event_attrs do
    %{
      all_day: false,
      description: "An event description",
      ends_at_time: "20:00",
      ends_on: "2026-05-10",
      location: "Community Hall, 123 Example Street",
      relay_policy: :internal_only,
      starts_at_time: "18:00",
      starts_on: "2026-05-10",
      title: "Shared Dinner",
      tz: "Etc/UTC"
    }
  end

  defp scope(actor, tenant), do: %Scope{actor: actor, tenant: tenant}
end
