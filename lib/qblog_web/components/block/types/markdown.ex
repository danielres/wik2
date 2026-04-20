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

    node_id_by_path = Wikilinks.nodes_to_id_map(nodes)
    wikilink_map = node_id_by_path |> Jason.encode!()
    wikilink_paths = node_id_by_path |> Map.keys() |> Jason.encode!()

    assigns =
      assigns
      |> assign(wikilink_map: wikilink_map)
      |> assign(wikilink_paths: wikilink_paths)

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
      data-wikilink-paths={@wikilink_paths}
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
    |> open_external_links_in_new_tab()
    |> patch_internal_wiki_links(scope)
  end

  defp open_external_links_in_new_tab(html) do
    Regex.replace(~r/<a href="https?:\/\/[^"]*"/, html, fn link ->
      link <> ~s( target="_blank" rel="noopener noreferrer")
    end)
  end

  defp patch_internal_wiki_links(html, %{tenant: %{name: group_name}})
       when is_binary(group_name) do
    Regex.replace(~r/<a href="\/#{Regex.escape(group_name)}\/wiki\/[^"]*"/, html, fn link ->
      link <> ~s( data-phx-link="patch" data-phx-link-state="push")
    end)
  end

  defp patch_internal_wiki_links(html, _scope), do: html

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
