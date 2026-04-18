defmodule QblogWeb.Components.Block.Types.Markdown do
  use QblogWeb, :html

  attr :block, :map, required: true
  attr :scope, :map, default: nil

  def render(assigns) do
    assigns =
      assigns
      |> assign(:html, assigns.block.data |> get_text() |> markdown_to_html(assigns.scope))

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

  def form_fields(assigns) do
    ~H"""
    <textarea
      id={"edit-block-markdown-textarea-#{@block.id}"}
      name={@form[:text].name}
      class="hidden"
    >{@form[:text].value || ""}</textarea>

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

  defp get_text(%{"text" => text}) when is_binary(text), do: text
  defp get_text(_data), do: ""

  defp markdown_to_html("", _scope), do: "<p>Empty Markdown block</p>"

  defp markdown_to_html(markdown, scope) do
    markdown
    |> render_wikilinks(scope)
    |> Earmark.as_html!(escape: true, compact_output: true)
    |> HtmlSanitizeEx.markdown_html()
  end

  defp render_wikilinks(markdown, %{tenant: %{name: group_name}}) when is_binary(group_name) do
    Regex.replace(~r/\[\[([^\]\n]+)\]\]/, markdown, fn wikilink, path ->
      path = String.trim(path)

      if safe_wikilink_path?(path) do
        "[#{path}](/#{group_name}/wiki/#{path})"
      else
        wikilink
      end
    end)
  end

  defp render_wikilinks(markdown, _scope), do: markdown

  defp safe_wikilink_path?(path) do
    Regex.match?(~r/^[A-Za-z0-9_-]+(\/[A-Za-z0-9_-]+)*$/, path)
  end
end
