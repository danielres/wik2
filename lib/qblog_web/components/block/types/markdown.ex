defmodule QblogWeb.Components.Block.Types.Markdown do
  use QblogWeb, :html

  attr :block, :map, required: true

  def render(assigns) do
    ~H"""
    <pre class={[
      "whitespace-pre-wrap",
      "overflow-x-auto"
    ]}><code>{@block.data["text"] || "Empty Markdown block"}</code></pre>
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
end
