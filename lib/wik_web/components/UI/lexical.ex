defmodule WikWeb.Components.UI.Lexical do
  use WikWeb, :html

  def components(assigns) do
    ~H"""
    <.toolbar block={@block} />
    <.floating_toolbar block={@block} />
    <.insert_menu block={@block} />
    <.wikilink_completion_menu block={@block} />
    <.youtube_dialog block={@block} />
    """
  end

  def floating_toolbar(assigns) do
    ~H"""
    <template id={"edit-block-markdown-floating-toolbar-template-#{@block.id}"}>
      <div class="LEXICAL_FLOATING_TOOLBAR" hidden>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Bold" data-command="bold">
          B
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Italic" data-command="italic">
          I
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Inline code" data-command="code">
          Code
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Add link" data-command="link">
          <.icon name="hero-link" />
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Remove link" data-command="unlink">
          <.icon name="hero-link-slash" />
        </button>
      </div>
    </template>
    """
  end

  def toolbar(assigns) do
    ~H"""
    <template id={"edit-block-markdown-toolbar-template-#{@block.id}"}>
      <div class={[
        "LEXICAL_TOOLBAR",
        "[&_button]:cursor-pointer"
      ]}>
        <button
          type="button"
          class="LEXICAL_TOOLBAR_BUTTON"
          title="Paragraph"
          data-command="paragraph"
        >
          P
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Heading 1" data-command="h1">
          H1
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Heading 2" data-command="h2">
          H2
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Heading 3" data-command="h3">
          H3
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Quote" data-command="quote">
          Quote
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Bold" data-command="bold">
          B
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Italic" data-command="italic">
          I
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Inline code" data-command="code">
          Code
        </button>
        <button
          type="button"
          class="LEXICAL_TOOLBAR_BUTTON"
          title="Bullet list"
          data-command="bullets"
        >
          <.icon name="hero-list-bullet" />
        </button>
        <button
          type="button"
          class="LEXICAL_TOOLBAR_BUTTON"
          title="Numbered list"
          data-command="numbers"
        >
          <.icon name="hero-numbered-list" />
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Task list" data-command="todo">
          <.icon name="hero-check" />
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Add link" data-command="link">
          <.icon name="hero-link" />
        </button>
        <button type="button" class="LEXICAL_TOOLBAR_BUTTON" title="Remove link" data-command="unlink">
          <.icon name="hero-link-slash" />
        </button>
      </div>
    </template>
    """
  end

  def insert_menu(assigns) do
    ~H"""
    <template id={"edit-block-markdown-insert-menu-template-#{@block.id}"}>
      <div class="LEXICAL_INSERT_MENU" hidden>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="paragraph">
          Paragraph
        </button>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="h1">
          Heading 1
        </button>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="h2">
          Heading 2
        </button>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="h3">
          Heading 3
        </button>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="quote">
          Quote
        </button>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="bullets">
          Bullet list
        </button>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="numbers">
          Numbered list
        </button>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="todo">
          Task list
        </button>
        <button type="button" class="LEXICAL_INSERT_MENU_BUTTON" data-insert-command="youtube">
          YouTube embed
        </button>
      </div>
    </template>
    """
  end

  def youtube_dialog(assigns) do
    ~H"""
    <template id={"edit-block-markdown-youtube-dialog-template-#{@block.id}"}>
      <dialog class="LEXICAL_YOUTUBE_DIALOG">
        <form method="dialog" class="LEXICAL_YOUTUBE_FORM">
          <div class="LEXICAL_YOUTUBE_TITLE">YouTube embed</div>
          <input
            type="text"
            required
            placeholder="https://www.youtube.com/watch?v=W-hwnJUT854"
            class="LEXICAL_YOUTUBE_INPUT"
            data-youtube-input
          />
          <div class="LEXICAL_YOUTUBE_ERROR" data-youtube-error hidden></div>
          <div class="LEXICAL_YOUTUBE_ACTIONS">
            <button type="button" class="LEXICAL_YOUTUBE_BUTTON secondary" data-youtube-cancel>
              Cancel
            </button>
            <button type="submit" class="LEXICAL_YOUTUBE_BUTTON primary">
              Insert
            </button>
          </div>
        </form>
      </dialog>
    </template>
    """
  end

  def wikilink_completion_menu(assigns) do
    ~H"""
    <template id={"edit-block-markdown-wikilink-completion-menu-template-#{@block.id}"}>
      <div class="LEXICAL_WIKILINK_MENU" role="listbox" hidden>
        <button
          type="button"
          class="LEXICAL_WIKILINK_OPTION"
          role="option"
          data-wikilink-completion-option
        >
          <span class="LEXICAL_WIKILINK_LABEL" data-wikilink-completion-label></span>
          <span class="LEXICAL_WIKILINK_KIND" data-wikilink-completion-kind></span>
        </button>
      </div>
    </template>
    """
  end
end
