defmodule QblogWeb.Components.Block.Types.Markdown do
  use QblogWeb, :html

  alias Qblog.Wiki.PageTree.Wikilinks

  attr :block, :map, required: true
  attr :page_tree, :map, required: true
  attr :scope, :map, default: nil

  def render(assigns) do
    %{"text" => md} = assigns.block.data
    scope = assigns.scope
    page_tree = assigns.page_tree
    html = md |> markdown_to_html(scope, page_tree)
    assigns = assigns |> assign(html: html)

    ~H"""
    <div
      data-testid="markdown-block"
      id={"markdown-block-#{@block.id}"}
      class={["BLOCK_MARKDOWN"]}
    >
      {raw(@html)}
    </div>
    """
  end

  attr :block, :map, required: true
  attr :form, :any, required: true
  attr :page_tree, :map, required: true
  attr :scope, :map, default: nil

  def form_fields(assigns) do
    nodes = assigns.page_tree.nodes

    wikilink_map =
      nodes
      |> Wikilinks.nodes_to_id_map()
      |> Jason.encode!()

    assigns = assigns |> assign(wikilink_map: wikilink_map)

    ~H"""
    <textarea
      id={"edit-block-markdown-textarea-#{@block.id}"}
      name={@form[:text].name}
      class="hidden"
    >{@form[:text].value || ""}</textarea>

    <input
      type="hidden"
      name={@form[:wikilink_map].name}
      value={@form[:wikilink_map].value || @wikilink_map}
    />

    <div
      id={"edit-block-markdown-editor-#{@block.id}"}
      phx-hook="MarkdownEditor"
      phx-update="ignore"
      data-textarea-id={"edit-block-markdown-textarea-#{@block.id}"}
      class=""
    >
    </div>
    """
  end

  defp markdown_to_html(markdown, scope, page_tree)
  defp markdown_to_html("", _scope, _page_tree), do: "<p>Empty Markdown block</p>"

  defp markdown_to_html(markdown, scope, page_tree) do
    markdown
    |> Wikilinks.nodes_to_paths(page_tree)
    |> render_visible_wikilinks(scope)
    |> Earmark.as_html!(escape: true, compact_output: true)
    |> HtmlSanitizeEx.markdown_html()
  end

  defp render_visible_wikilinks(markdown, %{tenant: %{name: group_name}})
       when is_binary(group_name) do
    Wikilinks.replace_visible(markdown, fn wikilink, path ->
      path = String.trim(path)

      if safe_visible_wikilink_path?(path) do
        "[#{path}](/#{group_name}/wiki/#{path})"
      else
        wikilink
      end
    end)
  end

  defp render_visible_wikilinks(markdown, _scope), do: markdown

  defp safe_visible_wikilink_path?(path) do
    Regex.match?(~r/^[A-Za-z0-9_-]+(\/[A-Za-z0-9_-]+)*$/, path)
  end
end
