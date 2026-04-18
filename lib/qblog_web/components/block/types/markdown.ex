defmodule QblogWeb.Components.Block.Types.Markdown do
  use QblogWeb, :html

  attr :block, :map, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign(:html, assigns.block.data |> get_text() |> markdown_to_html())

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

  defp markdown_to_html(""), do: "<p>Empty Markdown block</p>"

  defp markdown_to_html(markdown) do
    markdown
    |> Earmark.as_html!(escape: true, compact_output: true)
    |> HtmlSanitizeEx.markdown_html()
  end
end
