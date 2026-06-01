defmodule WikWeb.Components.Event.ExternalDetailsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest, only: [render_component: 2]

  alias WikWeb.Components.Event.ExternalDetails

  test "render preserves plain text descriptions with line breaks" do
    html =
      render_component(&ExternalDetails.render/1, %{
        item: %{
          title: "External dinner",
          status: :confirmed,
          description: "Line one\nLine two",
          all_day: false,
          location: nil,
          calendar_name: nil,
          source_url: nil,
          event_url: nil,
          tz: "Etc/UTC",
          starts_at: ~U[2026-06-01 18:00:00Z],
          ends_at: ~U[2026-06-01 20:00:00Z]
        },
        user_tz: "Etc/UTC"
      })

    assert html =~ "Line one\nLine two"
    assert html =~ "whitespace-pre-wrap"
  end

  test "render auto-links bare urls in plain text descriptions" do
    html =
      render_component(&ExternalDetails.render/1, %{
        item: %{
          title: "External dinner",
          status: :confirmed,
          description: "More info: https://sabinablumauer.si/blues-dance/\nBring friends",
          all_day: false,
          location: nil,
          calendar_name: nil,
          source_url: nil,
          event_url: nil,
          tz: "Etc/UTC",
          starts_at: ~U[2026-06-01 18:00:00Z],
          ends_at: ~U[2026-06-01 20:00:00Z]
        },
        user_tz: "Etc/UTC"
      })

    document = LazyHTML.from_fragment(html)

    assert document
           |> LazyHTML.query(~s(a[href="https://sabinablumauer.si/blues-dance/"]))
           |> Enum.any?()

    assert html =~ "Bring friends"
    assert html =~ "whitespace-pre-wrap"
  end

  test "render sanitizes html descriptions and keeps safe links" do
    html =
      render_component(&ExternalDetails.render/1, %{
        item: %{
          title: "External dinner",
          status: :confirmed,
          description:
            ~s|<a href="https://example.com">example</a><script>alert(1)</script><img src="https://example.com/x.png" onerror="alert(1)">|,
          all_day: false,
          location: nil,
          calendar_name: nil,
          source_url: nil,
          event_url: nil,
          tz: "Etc/UTC",
          starts_at: ~U[2026-06-01 18:00:00Z],
          ends_at: ~U[2026-06-01 20:00:00Z]
        },
        user_tz: "Etc/UTC"
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query(~s(a[href="https://example.com"])) |> Enum.any?()
    refute document |> LazyHTML.query("script") |> Enum.any?()
    refute document |> LazyHTML.query("img") |> Enum.any?()
    assert html =~ ~s(target="_blank")
    assert html =~ ~s(rel="noopener noreferrer")
    refute html =~ ~s(> target="_blank")
  end

  test "render unwraps google calendar redirect links to their real destination" do
    html =
      render_component(&ExternalDetails.render/1, %{
        item: %{
          title: "External dinner",
          status: :confirmed,
          description:
            ~s|<a href="https://www.google.com/url?q=http://www.werk36.de&amp;sa=D&amp;source=calendar">www.werk36.de</a>|,
          all_day: false,
          location: nil,
          calendar_name: nil,
          source_url: nil,
          event_url: nil,
          tz: "Etc/UTC",
          starts_at: ~U[2026-06-01 18:00:00Z],
          ends_at: ~U[2026-06-01 20:00:00Z]
        },
        user_tz: "Etc/UTC"
      })

    document = LazyHTML.from_fragment(html)

    assert document |> LazyHTML.query(~s(a[href="http://www.werk36.de"])) |> Enum.any?()
    refute html =~ "https://www.google.com/url?q="
  end

  test "render escapes rewritten hrefs after unwrapping google redirect links" do
    html =
      render_component(&ExternalDetails.render/1, %{
        item: %{
          title: "External dinner",
          status: :confirmed,
          description:
            ~s|<a href="https://www.google.com/url?q=https%3A%2F%2Fexample.com%2F%3Fa%3D1%26x%3D%22oops%22&amp;sa=D">example</a>|,
          all_day: false,
          location: nil,
          calendar_name: nil,
          source_url: nil,
          event_url: nil,
          tz: "Etc/UTC",
          starts_at: ~U[2026-06-01 18:00:00Z],
          ends_at: ~U[2026-06-01 20:00:00Z]
        },
        user_tz: "Etc/UTC"
      })

    assert html =~ ~s(href="https://example.com/?a=1&amp;x=&quot;oops&quot;")
    refute html =~ ~s(onclick=)
  end
end
