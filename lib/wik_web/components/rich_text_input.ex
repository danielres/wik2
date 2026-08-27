defmodule WikWeb.Components.RichTextInput do
  use WikWeb, :html

  alias WikWeb.Components.UI

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :name, :string, required: true
  attr :required, :boolean, default: false
  attr :value, :string, default: ""

  def field(assigns) do
    editor_key = String.replace(assigns.id, ~r/[^a-zA-Z0-9_-]/, "-")

    assigns =
      assigns
      |> assign(:block, %{id: editor_key})
      |> assign(:editor_key, editor_key)

    ~H"""
    <div class="fieldset" data-testid={"#{@id}-rich-text-field"}>
      <label class="label" for={"#{@id}-editor"}>{@label}</label>
      <textarea
        id={"#{@id}-textarea"}
        class="hidden"
        name={@name}
      >{@value || ""}</textarea>

      <UI.Lexical.components block={@block} />

      <div
        id={"#{@id}-editor"}
        aria-required={to_string(@required)}
        class="min-h-36 rounded-box border border-base-content/20 bg-base-100"
        data-floating-toolbar-template-id={"edit-block-markdown-floating-toolbar-template-#{@editor_key}"}
        data-insert-menu-template-id={"edit-block-markdown-insert-menu-template-#{@editor_key}"}
        data-link-editor-template-id={"edit-block-markdown-link-editor-template-#{@editor_key}"}
        data-member-wikilink-usernames="[]"
        data-tag-wikilink-names="[]"
        data-textarea-id={"#{@id}-textarea"}
        data-toolbar-template-id={"edit-block-markdown-toolbar-template-#{@editor_key}"}
        data-wikilink-completion-menu-template-id={"edit-block-markdown-wikilink-completion-menu-template-#{@editor_key}"}
        data-wikilink-paths="[]"
        data-youtube-dialog-template-id={"edit-block-markdown-youtube-dialog-template-#{@editor_key}"}
        phx-hook="LexicalEditor"
        phx-update="ignore"
      >
      </div>
    </div>
    """
  end
end
