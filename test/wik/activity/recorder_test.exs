defmodule Wik.Activity.RecorderTest do
  use Wik.DataCase, async: false

  import Wik.TestGenerators

  alias Wik.Activity.Entry
  alias Wik.Activity.Recorder
  alias Wik.Scope

  require Ash.Query

  test "collapses matching updates within fifteen minutes" do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = generate(membership(space: space, user: owner, type: :owner))
    first_time = ~U[2026-08-10 10:00:00.000000Z]

    attrs = entry_attrs(space, membership)

    assert {:ok, first_entry} = Recorder.record(attrs, now: first_time)

    assert {:ok, collapsed_entry} =
             Recorder.record(
               %{attrs | metadata: %{note: "Latest"}, subject_label: "Updated title"},
               now: DateTime.add(first_time, 14 * 60, :second)
             )

    assert first_entry.id == collapsed_entry.id
    assert collapsed_entry.occurrence_count == 2
    assert collapsed_entry.subject_label == "Updated title"
    assert collapsed_entry.metadata == %{"note" => "Latest"}
  end

  test "starts a new entry after the collapse window" do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = generate(membership(space: space, user: owner, type: :owner))
    first_time = ~U[2026-08-10 10:00:00.000000Z]
    attrs = entry_attrs(space, membership)

    assert {:ok, first_entry} = Recorder.record(attrs, now: first_time)

    assert {:ok, second_entry} =
             Recorder.record(attrs, now: DateTime.add(first_time, 16 * 60, :second))

    refute first_entry.id == second_entry.id
    assert Enum.map(list_entries(space), & &1.occurrence_count) == [1, 1]
  end

  test "space members can read entries and outsiders cannot" do
    owner = generate(user())
    outsider = generate(user())
    space = generate(space(author: owner))
    membership = generate(membership(space: space, user: owner, type: :owner))

    assert {:ok, _entry} = Recorder.record(entry_attrs(space, membership))

    assert {:ok, [_entry]} = Ash.read(Entry, scope: %Scope{actor: owner, tenant: space})
    assert {:ok, []} = Ash.read(Entry, scope: %Scope{actor: outsider, tenant: space})
  end

  defp entry_attrs(space, membership) do
    %{
      actor_label: "owner",
      actor_membership_id: membership.id,
      actor_username: "owner",
      category: :wiki,
      collapse_key: "page:019e7a02-59a6-7d0f-8a5a-bcf3cdf60322",
      collapsible?: true,
      kind: :page_updated,
      metadata: %{},
      space_id: space.id,
      subject_id: "019e7a02-59a6-7d0f-8a5a-bcf3cdf60322",
      subject_label: "Home",
      subject_path: "/#{space.slug}/wiki/home",
      subject_type: :page
    }
  end

  defp list_entries(space) do
    Entry
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.read!(authorize?: false, tenant: space.id)
  end
end
