defmodule Wik.Blocks.Types.GoogleCalendarTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Blocks
  alias Wik.Blocks.Block
  alias Wik.Scope

  describe "validate_data/1" do
    test "allows blank google calendar url on create" do
      actor = generate(user())

      assert {:ok, _block} =
               Ash.create(
                 Block,
                 %{
                   data: %{"title" => "", "url" => ""},
                   owner_user_id: actor.id,
                   type: :google_calendar
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when google calendar url is not a string" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"title" => "", "url" => 123},
                   owner_user_id: actor.id,
                   type: :google_calendar
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end

    test "fails when google calendar url is not an embed url" do
      actor = generate(user())

      assert {:error, _error} =
               Ash.create(
                 Block,
                 %{
                   data: %{"title" => "", "url" => "https://calendar.google.com/calendar/u/0/r"},
                   owner_user_id: actor.id,
                   type: :google_calendar
                 },
                 action: :create,
                 scope: scope(actor)
               )
    end
  end

  describe "update_block/3" do
    test "accepts a raw google calendar embed url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :google_calendar},
          scope: scope
        )

      embed_url =
        "https://calendar.google.com/calendar/embed?src=example%40gmail.com&ctz=Europe%2FBerlin"

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"title" => "", "url" => embed_url}, scope: scope)

      assert updated_block.data == %{"title" => "", "url" => embed_url}
    end

    test "accepts google calendar iframe embed code and stores only the url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :google_calendar},
          scope: scope
        )

      iframe =
        ~s(<iframe src="https://calendar.google.com/calendar/embed?src=example%40gmail.com&amp;ctz=Europe%2FBerlin"></iframe>)

      assert {:ok, updated_block} =
               Blocks.update_block(block, %{"title" => "", "url" => iframe}, scope: scope)

      assert updated_block.data == %{
               "title" => "",
               "url" =>
                 "https://calendar.google.com/calendar/embed?src=example%40gmail.com&ctz=Europe%2FBerlin"
             }
    end

    test "rejects a regular google calendar url" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :google_calendar},
          scope: scope
        )

      assert {:error, _error} =
               Blocks.update_block(
                 block,
                 %{"title" => "", "url" => "https://calendar.google.com/calendar/u/0/r"},
                 scope: scope
               )
    end

    test "rejects another embed provider instead of switching type" do
      actor = generate(user())
      scope = scope(actor)

      {:ok, block} =
        Blocks.create_user_owned_block(
          %{type: :google_calendar},
          scope: scope
        )

      soundcloud_embed_url =
        "https://w.soundcloud.com/player/?url=https%3A//api.soundcloud.com/tracks/293&color=%23ff5500"

      assert {:error, _error} =
               Blocks.update_block(block, %{"title" => "", "url" => soundcloud_embed_url},
                 scope: scope
               )
    end
  end

  defp scope(actor, tenant \\ nil) do
    %Scope{actor: actor, tenant: tenant}
  end
end
