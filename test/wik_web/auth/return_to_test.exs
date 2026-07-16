defmodule WikWeb.Auth.ReturnToTest do
  use ExUnit.Case, async: true

  alias WikWeb.Auth.ReturnTo

  test "allows relative paths" do
    assert ReturnTo.validate("/space/wiki/home?tab=open") == "/space/wiki/home?tab=open"
  end

  test "rejects external URLs and protocol-relative URLs" do
    assert ReturnTo.validate("https://evil.example") == "/"
    assert ReturnTo.validate("//evil.example") == "/"
  end

  test "rejects backslashes and control characters" do
    assert ReturnTo.validate("/\\evil.example") == "/"
    assert ReturnTo.validate("/me\nLocation: //evil.example") == "/"
  end

  test "rejects non-binary values" do
    assert ReturnTo.validate(nil) == "/"
  end
end
