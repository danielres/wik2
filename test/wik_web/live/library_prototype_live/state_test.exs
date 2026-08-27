defmodule WikWeb.LibraryPrototypeLive.StateTest do
  use ExUnit.Case, async: true

  alias WikWeb.LibraryPrototypeLive.State

  test "members can update and delete only entries they created while admins can manage all" do
    state = State.new()
    collection = State.find_collection(state, "places")

    assert {:ok, state, entry} =
             State.create_entry(state, collection, "member-one", false, %{
               "location" => "Berlin",
               "name" => "My place",
               "notes" => "",
               "phone" => "",
               "website" => ""
             })

    update_params = Map.put(entry.values, "name", "Updated place")

    assert {:error, :forbidden} =
             State.update_entry(state, collection, entry.id, "member-two", false, update_params)

    assert {:error, :forbidden} =
             State.delete_entry(state, collection.id, entry.id, "member-two", false)

    assert {:ok, state, updated_entry} =
             State.update_entry(state, collection, entry.id, "member-one", false, update_params)

    assert updated_entry.values["name"] == "Updated place"

    assert {:ok, _state, _entry} =
             State.delete_entry(state, collection.id, entry.id, "admin", true)
  end

  test "collection creation requires an explicit entry creation permission" do
    state = State.new()

    draft =
      state
      |> State.find_collection("places")
      |> Map.put(:name, "New places")
      |> Map.delete(:entry_creation_permission)

    assert {:error, "Choose who can add entries."} = State.create_collection(state, draft)

    assert {:ok, _state, collection} =
             State.create_collection(state, Map.put(draft, :entry_creation_permission, "admins"))

    assert collection.entry_creation_permission == :admins
  end

  test "collection permissions restrict entry creation to admins" do
    state = State.new()
    collection = State.find_collection(state, "places")

    assert State.can_create_entry?(collection, false)

    assert {:ok, state, collection} =
             State.update_entry_creation_permission(state, collection.id, "admins")

    refute State.can_create_entry?(collection, false)
    assert State.can_create_entry?(collection, true)

    params = %{
      "location" => "Berlin",
      "name" => "My place",
      "notes" => "",
      "phone" => "",
      "website" => ""
    }

    assert {:error, :forbidden} =
             State.create_entry(state, collection, "member", false, params)

    assert {:ok, _state, _entry} =
             State.create_entry(state, collection, "admin", true, params)
  end

  test "populated fields cannot change type and required fields cannot strand entries" do
    state = State.new()
    collection = State.find_collection(state, "places")
    website = Enum.find(collection.fields, &(&1.key == "website"))

    assert {:error, "Clear this field from every entry before changing its type."} =
             State.update_field(state, collection.id, website.id, %{
               "label" => "Website",
               "required" => "false",
               "type" => "text"
             })

    assert {:ok, state, collection, empty_field} =
             State.add_field(state, collection.id, %{
               "label" => "Opening hours",
               "required" => "false",
               "type" => "text"
             })

    assert {:error, "Fill this field in every entry before making it required."} =
             State.update_field(state, collection.id, empty_field.id, %{
               "label" => "Opening hours",
               "required" => "true",
               "type" => "text"
             })
  end

  test "deleting a field removes values only from its collection" do
    state = State.new()
    places = State.find_collection(state, "places")
    contacts = State.find_collection(state, "contacts")
    notes = Enum.find(places.fields, &(&1.key == "notes"))

    assert {:ok, state, _places} = State.delete_field(state, places.id, notes.id)
    assert State.find_entry(state, "entry-place").values["notes"] == nil
    assert State.find_entry(state, "entry-contact").values["notes"] != nil
    assert State.find_collection(state, contacts.slug).id == contacts.id
  end

  test "the title field can be relabelled but not weakened" do
    state = State.new()
    collection = State.find_collection(state, "places")
    title = List.first(collection.fields)

    assert {:ok, _state, collection, updated_title} =
             State.update_field(state, collection.id, title.id, %{"label" => "Place name"})

    assert updated_title.type == :title
    assert updated_title.required?
    assert List.first(collection.fields).label == "Place name"
  end
end
