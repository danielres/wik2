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

  test "accumulates consecutive targets and refreshes duplicate target details" do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = generate(membership(space: space, user: owner, type: :owner))
    first_time = ~U[2026-08-10 10:00:00.000000Z]
    first_id = Ash.UUIDv7.generate()
    second_id = Ash.UUIDv7.generate()
    attrs = consecutive_entry_attrs(space, membership, target(first_id, "First", "/first"))

    assert {:ok, first_entry} = Recorder.record(attrs, now: first_time)

    assert {:ok, second_entry} =
             Recorder.record(
               %{attrs | metadata: %{targets: [target(second_id, "Second", "/second")]}},
               now: DateTime.add(first_time, 60, :second)
             )

    assert {:ok, collapsed_entry} =
             Recorder.record(
               %{attrs | metadata: %{targets: [target(first_id, "Renamed", "/renamed")]}},
               now: DateTime.add(first_time, 120, :second)
             )

    assert first_entry.id == second_entry.id
    assert first_entry.id == collapsed_entry.id
    assert collapsed_entry.occurrence_count == 3

    assert collapsed_entry.metadata["targets"] == [
             %{"id" => first_id, "label" => "Renamed", "path" => "/renamed"},
             %{"id" => second_id, "label" => "Second", "path" => "/second"}
           ]
  end

  test "does not collapse consecutive targets across intervening activity" do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = generate(membership(space: space, user: owner, type: :owner))
    first_time = ~U[2026-08-10 10:00:00.000000Z]

    attrs =
      consecutive_entry_attrs(
        space,
        membership,
        target(Ash.UUIDv7.generate(), "First", "/first")
      )

    assert {:ok, first_entry} = Recorder.record(attrs, now: first_time)

    assert {:ok, _intervening_entry} =
             Recorder.record(
               %{entry_attrs(space, membership) | collapse_key: "other-activity"},
               now: DateTime.add(first_time, 60, :second)
             )

    assert {:ok, second_entry} =
             Recorder.record(
               %{
                 attrs
                 | metadata: %{targets: [target(Ash.UUIDv7.generate(), "Second", "/second")]}
               },
               now: DateTime.add(first_time, 120, :second)
             )

    refute first_entry.id == second_entry.id
  end

  test "does not collapse consecutive targets outside the collapse window" do
    owner = generate(user())
    space = generate(space(author: owner))
    membership = generate(membership(space: space, user: owner, type: :owner))
    first_time = ~U[2026-08-10 10:00:00.000000Z]

    attrs =
      consecutive_entry_attrs(
        space,
        membership,
        target(Ash.UUIDv7.generate(), "First", "/first")
      )

    assert {:ok, first_entry} = Recorder.record(attrs, now: first_time)

    assert {:ok, second_entry} =
             Recorder.record(
               %{
                 attrs
                 | metadata: %{targets: [target(Ash.UUIDv7.generate(), "Second", "/second")]}
               },
               now: DateTime.add(first_time, 16 * 60, :second)
             )

    refute first_entry.id == second_entry.id
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

  defp consecutive_entry_attrs(space, membership, target) do
    space
    |> entry_attrs(membership)
    |> Map.merge(%{
      collapse_key: "consecutive:page_created:actor-1",
      collapse_mode: :consecutive_targets,
      kind: :page_created,
      metadata: %{targets: [target]},
      subject_id: target.id,
      subject_label: target.label,
      subject_path: target.path
    })
  end

  defp target(id, label, path), do: %{id: id, label: label, path: path}

  defp list_entries(space) do
    Entry
    |> Ash.Query.sort(occurred_at: :desc)
    |> Ash.read!(authorize?: false, tenant: space.id)
  end
end
