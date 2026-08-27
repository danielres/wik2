defmodule WikWeb.LibraryPrototypeLive.SchemaTest do
  use ExUnit.Case, async: true

  alias WikWeb.LibraryPrototypeLive.Schema

  test "built-in templates are ordinary schemas and custom can reproduce them" do
    templates = Schema.built_in_templates()
    videos = Schema.find_template(templates, "videos")
    custom = Schema.find_template(templates, "custom")

    assert Enum.map(videos.fields, & &1.type) == [:title, :media, :text, :rich_text]
    assert Enum.map(custom.fields, & &1.type) == [:title]

    manually_recreated = %{Schema.instantiate_template(custom) | fields: videos.fields}

    assert Enum.map(manually_recreated.fields, &Map.drop(&1, [:id])) ==
             Enum.map(videos.fields, &Map.drop(&1, [:id]))
  end

  test "export and import round-trip a data-free collection blueprint" do
    template = Schema.built_in_templates() |> Schema.find_template("contacts")
    draft = Schema.instantiate_template(template)

    collection = %{
      creator_id: "must-not-leak",
      description: draft.description,
      entries: [%{id: "must-not-leak"}],
      fields:
        draft.fields ++
          [
            %{
              id: "must-not-leak",
              key: "category",
              label: "Category",
              options: ["Venue", "Landmark"],
              required?: false,
              type: :select
            }
          ],
      id: "must-not-leak",
      name: draft.name,
      slug: "must-not-leak"
    }

    json = Schema.export(collection)

    assert {:ok, imported} = Schema.import(json)
    assert imported.name == collection.name
    assert imported.description == collection.description

    assert Enum.map(imported.fields, &Map.drop(&1, [:id])) ==
             Enum.map(collection.fields, &Map.drop(&1, [:id]))

    refute json =~ "must-not-leak"

    assert %{
             "fields" => exported_fields,
             "format" => "wik-library-schema",
             "version" => 1
           } = Jason.decode!(json)

    refute exported_fields
           |> Enum.find(&(&1["key"] == "name"))
           |> Map.has_key?("options")

    assert exported_fields
           |> Enum.find(&(&1["key"] == "category"))
           |> Map.fetch!("options") == ["Venue", "Landmark"]
  end

  test "import rejects unsupported versions and malformed title fields" do
    unsupported =
      Jason.encode!(%{
        "collection" => %{"name" => "Places"},
        "fields" => [],
        "format" => "wik-library-schema",
        "version" => 99
      })

    assert {:error, "Schema version 99 is not supported."} = Schema.import(unsupported)

    missing_title =
      Jason.encode!(%{
        "collection" => %{"name" => "Places"},
        "fields" => [
          %{
            "key" => "notes",
            "label" => "Notes",
            "options" => [],
            "required" => false,
            "type" => "text"
          }
        ],
        "format" => "wik-library-schema",
        "version" => 1
      })

    assert {:error, "The first field must be the collection title."} =
             Schema.import(missing_title)
  end

  test "entry validation covers required and semantic fields" do
    fields = [
      %{id: "title", key: "name", label: "Name", options: [], required?: true, type: :title},
      %{id: "email", key: "email", label: "Email", options: [], required?: false, type: :email},
      %{id: "url", key: "url", label: "URL", options: [], required?: false, type: :url}
    ]

    assert {:error, errors} =
             Schema.entry_values(fields, %{
               "email" => "not-an-email",
               "name" => "",
               "url" => "example.org"
             })

    assert "Name: is required" in errors
    assert "Email: enter a valid email address" in errors
    assert "URL: enter a complete http or https URL" in errors
  end
end
