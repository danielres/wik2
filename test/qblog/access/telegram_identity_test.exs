defmodule Qblog.Access.TelegramIdentityTest do
  use Qblog.DataCase, async: true

  alias Qblog.Access

  describe "find_or_create_identity_from_telegram/1" do
    test "creates a user and external identity from Telegram claims" do
      assert {:ok, identity} =
               Access.find_or_create_identity_from_telegram(%{
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
      assert identity.user.email == nil
    end

    test "updates the external identity and keeps the existing user" do
      assert {:ok, identity} =
               Access.find_or_create_identity_from_telegram(%{
                 "given_name" => "Ada",
                 "preferred_username" => "ada",
                 "sub" => 42
               })

      assert {:ok, updated_identity} =
               Access.find_or_create_identity_from_telegram(%{
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
