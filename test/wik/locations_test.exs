defmodule Wik.LocationsTest do
  use ExUnit.Case, async: true

  alias Wik.Locations

  setup do
    previous = Application.get_env(:wik, Wik.Locations, [])
    Application.put_env(:wik, Wik.Locations, api_url: "https://example.test/location")

    on_exit(fn ->
      Application.put_env(:wik, Wik.Locations, previous)
    end)

    :ok
  end

  describe "search/2" do
    test "returns an empty list for blank queries" do
      assert {:ok, []} =
               Locations.search("   ", fn _url, _opts -> flunk("unexpected request") end)
    end

    test "maps Photon features to label/value options" do
      test_pid = self()

      http_get = fn url, opts ->
        send(test_pid, {:photon_request, url, opts})

        {:ok,
         %Req.Response{
           status: 200,
           body: %{
             "features" => [
               %{
                 "properties" => %{
                   "city" => "Berlin",
                   "country" => "Germany",
                   "housenumber" => "58",
                   "name" => "Café Einstein",
                   "street" => "Kurfürstenstraße"
                 }
               }
             ]
           }
         }}
      end

      assert {:ok, [%{label: label, value: value}]} = Locations.search("cafe", http_get)

      assert label == "Café Einstein, Kurfürstenstraße 58, Berlin, Germany"
      assert value == label

      assert_receive {:photon_request, url, opts}
      assert url == "https://example.test/location"
      assert opts == [params: [q: "cafe", limit: 5, lang: "en"]]
    end

    test "returns an http error for non-success responses" do
      http_get = fn _url, _opts ->
        {:ok, %Req.Response{status: 500, body: %{"error" => "boom"}}}
      end

      assert {:error, {:http_error, 500, %{"error" => "boom"}}} =
               Locations.search("berlin", http_get)
    end

    test "returns an empty list when location autocomplete is disabled" do
      Application.put_env(:wik, Wik.Locations, api_url: nil)

      assert {:ok, []} =
               Locations.search("berlin", fn _url, _opts -> flunk("unexpected request") end)
    end
  end
end
