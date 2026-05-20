defmodule WikWeb.Components.Block.Types.Markdown do
  use WikWeb, :html

  alias Wik.Accounts
  alias Wik.Wiki.PageTree.Wikilinks

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
      class={[
        "BLOCK_MARKDOWN",
        "[overflow-wrap:anywhere]"
      ]}
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

    node_id_by_title_path = Wikilinks.title_paths_to_node_id_map(nodes)
    wikilink_map = node_id_by_title_path |> Jason.encode!()
    wikilink_paths = node_id_by_title_path |> Map.keys() |> Jason.encode!()
    wikilink_member_map = assigns |> wikilink_member_map() |> Jason.encode!()
    wikilink_member_usernames = assigns |> wikilink_member_usernames() |> Jason.encode!()

    assigns =
      assigns
      |> assign(wikilink_map: wikilink_map)
      |> assign(wikilink_paths: wikilink_paths)
      |> assign(wikilink_member_map: wikilink_member_map)
      |> assign(wikilink_member_usernames: wikilink_member_usernames)

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

    <input
      type="hidden"
      name={@form[:wikilink_member_map].name}
      value={@form[:wikilink_member_map].value || @wikilink_member_map}
    />

    <div
      id={"edit-block-markdown-editor-#{@block.id}"}
      phx-hook="MarkdownEditor"
      phx-update="ignore"
      data-textarea-id={"edit-block-markdown-textarea-#{@block.id}"}
      data-wikilink-paths={@wikilink_paths}
      data-member-wikilink-usernames={@wikilink_member_usernames}
      class=""
    >
    </div>
    """
  end

  defp markdown_to_html(markdown, scope, page_tree)
  defp markdown_to_html("", _scope, _page_tree), do: "<p>Empty Markdown block</p>"

  defp markdown_to_html(markdown, scope, page_tree) do
    member_id_to_username_map = scope |> membership_id_to_username_map()

    markdown
    |> Wikilinks.nodes_to_title_paths(page_tree)
    |> Wikilinks.memberships_to_usernames(member_id_to_username_map)
    |> render_visible_wikilinks(scope, page_tree, member_id_to_username_map)
    |> Earmark.as_html!(escape: true, compact_output: true)
    |> HtmlSanitizeEx.markdown_html()
    |> open_external_links_in_new_tab()
    |> patch_internal_wiki_links(scope)
    |> mark_missing_wikilinks()
  end

  defp open_external_links_in_new_tab(html) do
    Regex.replace(~r/<a href="https?:\/\/[^"]*"/, html, fn link ->
      link <> ~s( target="_blank" rel="noopener noreferrer")
    end)
  end

  defp patch_internal_wiki_links(html, %{tenant: %{slug: group_slug}})
       when is_binary(group_slug) do
    Regex.replace(~r/<a href="\/#{Regex.escape(group_slug)}\/wiki\/[^"]*"/, html, fn link ->
      link <> ~s( data-phx-link="patch" data-phx-link-state="push")
    end)
  end

  defp patch_internal_wiki_links(html, _scope), do: html

  defp render_visible_wikilinks(
         markdown,
         %{tenant: %{slug: group_slug}},
         %{nodes: nodes},
         member_id_to_username_map
       )
       when is_binary(group_slug) do
    title_path_to_slug_path = Wikilinks.title_paths_to_slug_path_map(nodes)

    member_username_to_membership_id_map =
      member_id_to_username_map
      |> Map.values()
      |> Map.new(&{&1, true})

    Wikilinks.replace_visible(markdown, fn wikilink, path ->
      title_path = path |> String.trim()
      username = String.trim_leading(title_path, "@")

      cond do
        title_path == "" ->
          wikilink

        username != title_path and Map.has_key?(member_username_to_membership_id_map, username) ->
          "[#{title_path}](/#{group_slug}/wiki/members/#{username})"

        username != title_path ->
          wikilink

        slug_path = Map.get(title_path_to_slug_path, title_path) ->
          "[#{title_path}](/#{group_slug}/wiki/#{slug_path})"

        slug_path = Wikilinks.slug_path_from_title_path(title_path) ->
          query = URI.encode_query(%{"title_path" => title_path})
          "[#{title_path}](/#{group_slug}/wiki/#{slug_path}?#{query})"

        true ->
          wikilink
      end
    end)
  end

  defp render_visible_wikilinks(markdown, _scope, _page_tree, _member_id_to_username_map),
    do: markdown

  defp mark_missing_wikilinks(html) do
    Regex.replace(~r/<a ([^>]*href="[^"]*\?title_path=[^"]*"[^>]*)>/, html, fn _match, attrs ->
      ~s(<a #{attrs} data-wikilink-status="missing">)
    end)
  end

  defp wikilink_member_map(%{scope: %{tenant: %{id: group_id}}}) when is_binary(group_id),
    do: Accounts.username_to_membership_id_map(group_id)

  defp wikilink_member_map(_assigns), do: %{}

  defp wikilink_member_usernames(assigns) do
    assigns
    |> wikilink_member_map()
    |> Map.keys()
  end

  defp membership_id_to_username_map(%{tenant: %{id: group_id}}) when is_binary(group_id),
    do: Accounts.membership_id_to_username_map(group_id)

  defp membership_id_to_username_map(_scope), do: %{}
end
