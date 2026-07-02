defmodule Wik.Access.Google.IdentityTest do
  use Wik.DataCase, async: true

  import Wik.TestGenerators

  alias Wik.Access

  describe "google_find_or_create_identity/1" do
    test "creates a user and external identity from verified Google claims" do
      assert {:ok, identity} =
               Access.google_find_or_create_identity(%{
                 "email" => "Ada@Example.COM",
                 "email_verified" => true,
                 "family_name" => "Lovelace",
                 "given_name" => "Ada",
                 "name" => "Ada Lovelace",
                 "picture" => "https://google.example/ada.png",
                 "sub" => "google-42"
               })

      assert identity.provider == :google
      assert identity.provider_user_id == "google-42"
      assert identity.email == "ada@example.com"
      assert identity.display_name == "Ada Lovelace"
      assert identity.avatar_url == "https://google.example/ada.png"
      assert identity.metadata["sub"] == "google-42"
      assert identity.metadata["email_verified"] == true
      assert identity.user.email |> to_string() == "ada@example.com"
    end

    test "attaches to an existing user with the same verified email" do
      user = generate(user(email: "ada@example.com"))

      assert {:ok, identity} =
               Access.google_find_or_create_identity(%{
                 "email" => "ADA@example.com",
                 "email_verified" => true,
                 "name" => "Ada Lovelace",
                 "sub" => "google-42"
               })

      assert identity.user.id == user.id
      assert identity.email == "ada@example.com"
    end

    test "rejects blank google email" do
      assert {:error, :email_required} =
               Access.google_find_or_create_identity(%{
                 "email" => " ",
                 "email_verified" => true,
                 "name" => "Ada Lovelace",
                 "sub" => "google-42"
               })
    end

    test "rejects non-binary google email" do
      assert {:error, :email_required} =
               Access.google_find_or_create_identity(%{
                 "email" => nil,
                 "email_verified" => true,
                 "name" => "Ada Lovelace",
                 "sub" => "google-42"
               })
    end

    test "updates the external identity and keeps the existing user" do
      assert {:ok, identity} =
               Access.google_find_or_create_identity(%{
                 "email" => "ada@example.com",
                 "email_verified" => true,
                 "name" => "Ada",
                 "sub" => "google-42"
               })

      assert {:ok, updated_identity} =
               Access.google_find_or_create_identity(%{
                 "email" => "ada@example.com",
                 "email_verified" => true,
                 "name" => "Ada Lovelace",
                 "picture" => "https://google.example/ada.png",
                 "sub" => "google-42"
               })

      assert updated_identity.id == identity.id
      assert updated_identity.user.id == identity.user.id
      assert updated_identity.display_name == "Ada Lovelace"
      assert updated_identity.avatar_url == "https://google.example/ada.png"
    end
  end
end
