defmodule WikWeb.LexicalEditorTestLive do
  use WikWeb, :live_view

  alias Wik.Wiki.PageTree
  alias WikWeb.Components.Block.Types.Markdown

  @initial_markdown "Start with selected text"

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:block, %{id: "browser-test", data: %{"text" => @initial_markdown}})
     |> assign(:editor_mounted?, true)
     |> assign(:form, form())
     |> assign(:page_tree, %PageTree{nodes: []})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-3xl p-8">
      <button data-testid="toggle-editor" phx-click="toggle-editor" type="button">
        Toggle editor
      </button>

      <.form :if={@editor_mounted?} for={@form} id="browser-test-form">
        <Markdown.form_fields
          block={@block}
          form={@form}
          page_tree={@page_tree}
          scope={%{}}
        />
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("toggle-editor", _params, socket) do
    {:noreply, update(socket, :editor_mounted?, &(!&1))}
  end

  defp form do
    to_form(
      %{
        "text" => @initial_markdown,
        "wikilink_map" => "{}",
        "wikilink_member_map" => "{}",
        "wikilink_tag_map" => "{}"
      },
      as: :block
    )
  end
end
