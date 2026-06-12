defmodule Wik.Access.Providers.GoogleTest do
  use ExUnit.Case, async: true

  alias Wik.Access.Providers.Google

  test "verified_email?/1 accepts boolean and string true" do
    assert Google.verified_email?(%{"email_verified" => true})
    assert Google.verified_email?(%{"email_verified" => "true"})
    refute Google.verified_email?(%{"email_verified" => false})
    refute Google.verified_email?(%{})
  end
end
