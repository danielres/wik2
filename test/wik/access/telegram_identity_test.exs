defmodule Wik.Access.TelegramIdentityTest do
  use Wik.DataCase, async: true

  alias Wik.Access

  describe "telegram_find_or_create_identity/1" do
    test "creates a user and external identity from Telegram claims" do
      assert {:ok, identity} =
               Access.telegram_find_or_create_identity(%{
                 "family_name" => "Lovelace",
                 "given_name" => "Ada",
                 "picture" => "https://telegram.example/ada.png",
                 "preferred_username" => "ada",
                 "sub" => 42
               })

      assert identity.provider == :telegram
      assert identity.provider_user_id == "42"
      assert identity.display_name == "Ada Lovelace"
      assert identity.username == "ada"
      assert identity.avatar_url == "https://telegram.example/ada.png"
      assert identity.metadata["sub"] == 42
      assert identity.metadata["preferred_username"] == "ada"
      refute Map.has_key?(identity.metadata, "hash")
      assert identity.user.email == nil
    end

    test "updates the external identity and keeps the existing user" do
      assert {:ok, identity} =
               Access.telegram_find_or_create_identity(%{
                 "given_name" => "Ada",
                 "preferred_username" => "ada",
                 "sub" => 42
               })

      assert {:ok, updated_identity} =
               Access.telegram_find_or_create_identity(%{
                 "given_name" => "Augusta",
                 "preferred_username" => "augusta",
                 "sub" => 42
               })

      assert updated_identity.id == identity.id
      assert updated_identity.user.id == identity.user.id
      assert updated_identity.display_name == "Augusta"
      assert updated_identity.username == "augusta"
    end
  end
end
