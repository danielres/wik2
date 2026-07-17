defmodule WikWeb.Components.Block.Types.Markdown do
  use WikWeb, :html

  alias Wik.Accounts
  alias Wik.Tags
  alias Wik.Wiki.PageTree.Wikilinks
  alias WikWeb.Components.UI

  attr :block, :map, required: true
  attr :editing?, :boolean, default: false
  attr :form, :map, required: true
  attr :page_tree, :map, required: true
  attr :scope, :map, required: true
  attr :id, :string, required: true
  attr :submit, :string, required: true
  attr :cancel, :string, required: true
  attr :text, :string, default: nil

  def editable(assigns) do
    ~H"""
    <.form
      :if={@editing? and @block != nil and @form != nil}
      for={@form}
      id={"#{@id}-form"}
      phx-submit={@submit}
    >
      <.form_fields
        block={@block}
        form={@form}
        page_tree={@page_tree}
        scope={@scope}
      />

      <div class="mt-3 flex justify-end gap-2">
        <button
          class="btn btn-sm btn-ghost"
          data-testid={"#{@id}-cancel"}
          phx-click={@cancel}
          type="button"
        >
          Cancel
        </button>

        <button
          class="btn btn-sm btn-accent btn-soft"
          data-testid={"#{@id}-submit"}
        >
          Save
        </button>
      </div>
    </.form>

    <.render
      :if={!@editing? and @block != nil}
      block={@block}
      page_tree={@page_tree}
      scope={@scope}
      text={@text}
    />
    """
  end

  attr :block, :map, required: true
  attr :page_tree, :map, required: true
  attr :scope, :map, default: nil
  attr :text, :string, default: nil

  def render(assigns) do
    md = assigns.text || Map.get(assigns.block.data, "text", "")
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
    wikilink_member_usernames = wikilink_member_paths(assigns, nodes) |> Jason.encode!()
    wikilink_tag_map = assigns |> wikilink_tag_map() |> Jason.encode!()
    wikilink_tag_names = assigns |> wikilink_tag_names() |> Jason.encode!()

    assigns =
      assigns
      |> assign(wikilink_map: wikilink_map)
      |> assign(wikilink_paths: wikilink_paths)
      |> assign(wikilink_member_map: wikilink_member_map)
      |> assign(wikilink_member_usernames: wikilink_member_usernames)
      |> assign(wikilink_tag_map: wikilink_tag_map)
      |> assign(wikilink_tag_names: wikilink_tag_names)

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

    <input
      type="hidden"
      name={@form[:wikilink_tag_map].name}
      value={@form[:wikilink_tag_map].value || @wikilink_tag_map}
    />

    <UI.Lexical.components block={@block} />

    <div
      id={"edit-block-markdown-editor-#{@block.id}"}
      phx-hook="LexicalEditor"
      phx-update="ignore"
      data-textarea-id={"edit-block-markdown-textarea-#{@block.id}"}
      data-toolbar-template-id={"edit-block-markdown-toolbar-template-#{@block.id}"}
      data-floating-toolbar-template-id={"edit-block-markdown-floating-toolbar-template-#{@block.id}"}
      data-link-editor-template-id={"edit-block-markdown-link-editor-template-#{@block.id}"}
      data-insert-menu-template-id={"edit-block-markdown-insert-menu-template-#{@block.id}"}
      data-wikilink-completion-menu-template-id={"edit-block-markdown-wikilink-completion-menu-template-#{@block.id}"}
      data-youtube-dialog-template-id={"edit-block-markdown-youtube-dialog-template-#{@block.id}"}
      data-wikilink-paths={@wikilink_paths}
      data-member-wikilink-usernames={@wikilink_member_usernames}
      data-tag-wikilink-names={@wikilink_tag_names}
      class=""
    >
    </div>
    """
  end

  defp markdown_to_html(markdown, scope, page_tree)
  defp markdown_to_html("", _scope, _page_tree), do: "<p>Empty Markdown block</p>"

  defp markdown_to_html(markdown, scope, page_tree) do
    member_id_to_username_map = scope |> membership_id_to_username_map()
    tag_id_to_name_map = scope |> tag_id_to_name_map()
    tag_name_to_slug_map = scope |> tag_name_to_slug_map()

    markdown
    |> Wikilinks.nodes_to_title_paths(page_tree)
    |> Wikilinks.memberships_to_usernames(member_id_to_username_map)
    |> Wikilinks.tags_to_tag_names(tag_id_to_name_map)
    |> mask_unresolved_canonical_tag_wikilinks()
    |> render_visible_wikilinks(scope, page_tree, member_id_to_username_map, tag_name_to_slug_map)
    |> strip_raw_iframes()
    |> render_markdown()
    |> render_youtube_embed_images()
    |> wrap_tables()
    |> restore_unresolved_canonical_tag_wikilinks()
    |> open_external_links_in_new_tab()
    |> patch_internal_wiki_links(scope)
    |> mark_missing_wikilinks()
  end

  defp render_markdown(markdown) do
    MDEx.new(markdown: markdown)
    |> MDExGFM.attach()
    |> MDEx.to_html!(
      extension: [
        autolink: true,
        block_directive: true,
        table: true,
        strikethrough: true,
        tasklist: true
      ],
      render: [
        unsafe: true
      ],
      sanitize: markdown_sanitize_options()
    )
  end

  defp markdown_sanitize_options do
    MDEx.Document.default_sanitize_options()
    |> Keyword.put(:add_tags, ["input", "img"])
    |> Keyword.put(:add_tag_attributes, %{
      "input" => ["checked", "disabled", "type"],
      "img" => ["alt", "src", "title"]
    })
  end

  @raw_iframe_regex ~r/<iframe\b[^>]*>.*?<\/iframe>/is

  defp strip_raw_iframes(markdown) do
    Regex.replace(@raw_iframe_regex, markdown, "")
  end

  @table_regex ~r/<table(?:\s[^>]*)?>.*?<\/table>/s

  defp wrap_tables(html) do
    Regex.replace(@table_regex, html, fn table ->
      ~s(<div class="table_wrapper">#{table}</div>)
    end)
  end

  @img_tag_regex ~r/<img\b[^>]*>/i
  @src_attr_regex ~r/\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i

  defp render_youtube_embed_images(html) do
    Regex.replace(@img_tag_regex, html, fn img ->
      case img |> html_src() |> youtube_embed_id() do
        nil -> ""
        video_id -> youtube_iframe(video_id)
      end
    end)
  end

  defp html_src(html) do
    case Regex.run(@src_attr_regex, html, capture: :all_but_first) do
      nil -> nil
      captures -> Enum.find(captures, &(is_binary(&1) and byte_size(&1) > 0))
    end
  end

  defp youtube_embed_id("https://www.youtube-nocookie.com/embed/" <> video_id) do
    if Regex.match?(~r/^[A-Za-z0-9_-]{11}$/, video_id), do: video_id
  end

  defp youtube_embed_id(_src), do: nil

  defp youtube_iframe(video_id) do
    """
    <iframe
      width="560"
      height="315"
      src="https://www.youtube-nocookie.com/embed/#{video_id}"
      frameborder="0"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
      allowfullscreen=""
      title="YouTube video"
    >
    </iframe>
    """
  end

  defp open_external_links_in_new_tab(html) do
    Regex.replace(~r/<a href="https?:\/\/[^"]*"/, html, fn link ->
      link <> ~s( target="_blank" rel="noopener noreferrer")
    end)
  end

  defp patch_internal_wiki_links(html, %{tenant: %{slug: space_slug}})
       when is_binary(space_slug) do
    Regex.replace(
      ~r/<a href="\/#{Regex.escape(space_slug)}(?:\/wiki\/|\/tags\/|\/topics\/)[^"]*"/,
      html,
      fn link ->
        link <> ~s( data-phx-link="patch" data-phx-link-state="push")
      end
    )
  end

  defp patch_internal_wiki_links(html, _scope), do: html

  defp render_visible_wikilinks(
         markdown,
         %{tenant: %{slug: space_slug}},
         %{nodes: nodes},
         member_id_to_username_map,
         tag_name_to_slug_map
       )
       when is_binary(space_slug) do
    title_path_to_slug_path = Wikilinks.title_paths_to_slug_path_map(nodes)

    member_username_to_membership_id_map =
      member_id_to_username_map
      |> Map.values()
      |> Map.new(&{&1, true})

    Wikilinks.replace_visible(markdown, fn wikilink, path ->
      title_path = path |> String.trim()
      tag_name = title_path |> String.trim_leading("#") |> String.trim()
      member_path = String.trim_leading(title_path, "@")
      {username, member_suffix} = split_member_path(member_path)

      cond do
        title_path == "" ->
          wikilink

        tag_name != title_path and Map.has_key?(tag_name_to_slug_map, tag_name) ->
          slug = Map.fetch!(tag_name_to_slug_map, tag_name)
          "[#{"#" <> tag_name}](/#{space_slug}/topics/#{slug})"

        tag_name != title_path ->
          wikilink

        member_path != title_path and Map.has_key?(member_username_to_membership_id_map, username) ->
          "[#{title_path}](/#{space_slug}/wiki/members/#{username}#{member_suffix})"

        member_path != title_path ->
          wikilink

        slug_path = Map.get(title_path_to_slug_path, title_path) ->
          "[#{title_path}](/#{space_slug}/wiki/#{slug_path})"

        slug_path = Wikilinks.slug_path_from_title_path(title_path) ->
          query = URI.encode_query(%{"title_path" => title_path})
          "[#{title_path}](/#{space_slug}/wiki/#{slug_path}?#{query})"

        true ->
          wikilink
      end
    end)
  end

  defp render_visible_wikilinks(
         markdown,
         _scope,
         _page_tree,
         _member_id_to_username_map,
         _tag_name_to_slug_map
       ),
       do: markdown

  defp mask_unresolved_canonical_tag_wikilinks(markdown) do
    Regex.replace(~r/\[\[tag:([^\]\n]+)\]\]/, markdown, fn _wikilink, tag_id ->
      "WIK_UNRESOLVED_TAG(#{tag_id})"
    end)
  end

  defp restore_unresolved_canonical_tag_wikilinks(html) do
    Regex.replace(~r/WIK_UNRESOLVED_TAG\(([^)\n]+)\)/, html, fn _match, tag_id ->
      "[[tag:#{tag_id}]]"
    end)
  end

  defp mark_missing_wikilinks(html) do
    Regex.replace(~r/<a ([^>]*href="[^"]*\?title_path=[^"]*"[^>]*)>/, html, fn _match, attrs ->
      ~s(<a #{attrs} data-wikilink-status="missing">)
    end)
  end

  defp wikilink_member_map(%{scope: %{tenant: %{id: space_id}}}) when is_binary(space_id),
    do: Accounts.username_to_membership_id_map(space_id)

  defp wikilink_member_map(_assigns), do: %{}

  defp wikilink_member_usernames(assigns) do
    assigns
    |> wikilink_member_map()
    |> Map.keys()
  end

  defp wikilink_member_paths(assigns, nodes) do
    usernames = wikilink_member_usernames(assigns)

    (usernames ++ Wikilinks.member_profile_paths(nodes, usernames))
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp wikilink_tag_map(%{scope: %{tenant: %{id: space_id}}}) when is_binary(space_id),
    do: Tags.tag_name_to_id_map(space_id)

  defp wikilink_tag_map(_assigns), do: %{}

  defp wikilink_tag_names(assigns) do
    assigns
    |> wikilink_tag_map()
    |> Map.keys()
    |> Enum.sort()
  end

  defp membership_id_to_username_map(%{tenant: %{id: space_id}}) when is_binary(space_id),
    do: Accounts.membership_id_to_username_map(space_id)

  defp membership_id_to_username_map(_scope), do: %{}

  defp tag_id_to_name_map(%{tenant: %{id: space_id}}) when is_binary(space_id),
    do: Tags.tag_id_to_name_map(space_id)

  defp tag_id_to_name_map(_scope), do: %{}

  defp tag_name_to_slug_map(%{tenant: %{id: space_id}}) when is_binary(space_id),
    do: Tags.tag_name_to_slug_map(space_id)

  defp tag_name_to_slug_map(_scope), do: %{}

  defp split_member_path(member_path) when is_binary(member_path) do
    case String.split(member_path, "/", parts: 2) do
      [username] -> {username, ""}
      [username, suffix] -> {username, "/" <> suffix}
    end
  end
end
