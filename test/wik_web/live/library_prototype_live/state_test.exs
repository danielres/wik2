defmodule WikWeb.LibraryPrototypeLive.StateTest do
  use ExUnit.Case, async: true

  alias WikWeb.LibraryPrototypeLive.State

  test "members can update and delete only entries they created while admins can manage all" do
    state = State.new()
    type = State.find_type(state, "place")

    assert {:ok, state, entry} =
             State.create_entry(state, type, "member-one", false, %{
               "location" => "Berlin",
               "name" => "My place",
               "notes" => "",
               "phone" => "",
               "website" => ""
             })

    update_params = Map.put(entry.values, "name", "Updated place")

    assert {:error, :forbidden} =
             State.update_entry(state, type, entry.id, "member-two", false, update_params)

    assert {:error, :forbidden} =
             State.delete_entry(state, type.id, entry.id, "member-two", false)

    assert {:ok, state, updated_entry} =
             State.update_entry(state, type, entry.id, "member-one", false, update_params)

    assert updated_entry.values["name"] == "Updated place"

    assert {:ok, _state, _entry} =
             State.delete_entry(state, type.id, entry.id, "admin", true)
  end

  test "type creation requires an explicit entry creation permission" do
    state = State.new()

    draft =
      state
      |> State.find_type("place")
      |> Map.put(:name, "New places")
      |> Map.delete(:entry_creation_permission)

    assert {:error, "Choose who can add entries."} = State.create_type(state, draft)

    assert {:ok, _state, type} =
             State.create_type(state, Map.put(draft, :entry_creation_permission, "admins"))

    assert type.entry_creation_permission == :admins
  end

  test "type permissions restrict entry creation to admins" do
    state = State.new()
    type = State.find_type(state, "place")

    assert State.can_create_entry?(type, false)

    assert {:ok, state, type} =
             State.update_entry_creation_permission(state, type.id, "admins")

    refute State.can_create_entry?(type, false)
    assert State.can_create_entry?(type, true)

    params = %{
      "location" => "Berlin",
      "name" => "My place",
      "notes" => "",
      "phone" => "",
      "website" => ""
    }

    assert {:error, :forbidden} =
             State.create_entry(state, type, "member", false, params)

    assert {:ok, _state, _entry} =
             State.create_entry(state, type, "admin", true, params)
  end

  test "populated fields cannot change type and required fields cannot strand entries" do
    state = State.new()
    type = State.find_type(state, "place")
    website = Enum.find(type.fields, &(&1.key == "website"))

    assert {:error, "Clear this field from every entry before changing its type."} =
             State.update_field(state, type.id, website.id, %{
               "label" => "Website",
               "required" => "false",
               "type" => "text"
             })

    assert {:ok, state, type, empty_field} =
             State.add_field(state, type.id, %{
               "label" => "Opening hours",
               "required" => "false",
               "type" => "text"
             })

    assert {:error, "Fill this field in every entry before making it required."} =
             State.update_field(state, type.id, empty_field.id, %{
               "label" => "Opening hours",
               "required" => "true",
               "type" => "text"
             })
  end

  test "deleting a field removes values only from its type" do
    state = State.new()
    places = State.find_type(state, "place")
    contacts = State.find_type(state, "contact")
    notes = Enum.find(places.fields, &(&1.key == "notes"))

    assert {:ok, state, _places} = State.delete_field(state, places.id, notes.id)
    assert State.find_entry(state, "entry-place").values["notes"] == nil
    assert State.find_entry(state, "entry-contact").values["notes"] != nil
    assert State.find_type(state, contacts.slug).id == contacts.id
  end

  test "the title field can be relabelled but not weakened" do
    state = State.new()
    type = State.find_type(state, "place")
    title = List.first(type.fields)

    assert {:ok, _state, type, updated_title} =
             State.update_field(state, type.id, title.id, %{"label" => "Place name"})

    assert updated_title.type == :title
    assert updated_title.required?
    assert List.first(type.fields).label == "Place name"
  end

  test "filters a unified feed by any topic and any type" do
    state = State.new()
    berlin = topic("berlin", "Berlin")
    software = topic("software", "Software")
    place = State.find_type(state, "place")
    video = State.find_type(state, "video")

    assert Enum.map(State.filter_entries(state, [berlin, software], [], []), & &1.id) == [
             "entry-place",
             "entry-contact",
             "entry-video",
             "entry-music"
           ]

    assert Enum.map(
             State.filter_entries(state, [berlin, software], [berlin.id, software.id], []),
             & &1.id
           ) == ["entry-place", "entry-video"]

    assert Enum.map(
             State.filter_entries(
               state,
               [berlin, software],
               [berlin.id, software.id],
               [place.id]
             ),
             & &1.id
           ) == ["entry-place"]

    assert Enum.map(State.filter_entries(state, [berlin, software], [], [video.id]), & &1.id) == [
             "entry-video"
           ]
  end

  test "lists only topics assigned automatically or manually" do
    state = State.new()
    berlin = topic("berlin", "Berlin")
    unassigned = topic("unassigned", "Unassigned")

    assert State.assigned_topics(state, [berlin, unassigned]) == [berlin]

    assert {:ok, state, _contribution} =
             State.upsert_topic_contribution(
               state,
               "entry-place",
               "member-one",
               unassigned.id,
               "7"
             )

    assert State.assigned_topics(state, [berlin, unassigned]) == [berlin, unassigned]
  end

  test "automatic topics support aliases, disabling, and entry exclusions" do
    state = State.new()
    community = topic("community", "Community")
    video = State.find_entry(state, "entry-video")
    video_type = State.find_type(state, "video")

    assert [%{automatic?: true, tag: ^community}] =
             State.topic_summaries(state, video, video_type, [community])

    local = topic("local", "Local community")
    assert State.topic_summaries(state, video, video_type, [local]) == []

    state = State.add_topic_alias(state, local.id, "local-first")
    assert [%{tag: ^local}] = State.topic_summaries(state, video, video_type, [local])

    state = State.dismiss_automatic_topic(state, video.id, local.id)
    assert State.topic_summaries(state, video, video_type, [local]) == []

    state = State.toggle_topic_rule(state, community.id)
    assert State.topic_summaries(state, video, video_type, [community]) == []
  end

  test "manual member contributions replace automatic topics and average relevance" do
    state = State.new()
    community = topic("community", "Community")
    entry = State.find_entry(state, "entry-place")
    type = State.find_type(state, "place")

    assert {:ok, state, _contribution} =
             State.upsert_topic_contribution(state, entry.id, "member-one", community.id, "6")

    assert {:ok, state, _contribution} =
             State.upsert_topic_contribution(state, entry.id, "member-two", community.id, "10")

    assert [summary] = State.topic_summaries(state, entry, type, [community], "member-one")
    refute summary.automatic?
    assert summary.average_relevancy == 8
    assert summary.count == 2
    assert summary.current_member_contribution.membership_id == "member-one"

    assert {:ok, state} =
             State.remove_topic_contribution(state, entry.id, "member-one", community.id)

    assert [summary] = State.topic_summaries(state, entry, type, [community], "member-one")
    assert summary.average_relevancy == 10
    assert summary.current_member_contribution == nil
  end

  test "used types cannot be deleted" do
    state = State.new()
    place = State.find_type(state, "place")

    assert {:error, "This type is used by 1 entry."} = State.delete_type(state, place.id)

    draft =
      state
      |> State.find_type("place")
      |> Map.put(:entry_creation_permission, "members")
      |> Map.put(:name, "Unused")

    assert {:ok, state, unused} = State.create_type(state, draft)
    assert {:ok, _state, ^unused} = State.delete_type(state, unused.id)
  end

  defp topic(id, name), do: %{id: id, name: name, slug: id}
end
