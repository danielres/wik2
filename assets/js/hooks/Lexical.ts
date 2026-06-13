import { createEmptyHistoryState, registerHistory } from "@lexical/history";
import { $toggleLink, LinkNode } from "@lexical/link";
import {
  INSERT_CHECK_LIST_COMMAND,
  INSERT_ORDERED_LIST_COMMAND,
  INSERT_UNORDERED_LIST_COMMAND,
  ListItemNode,
  ListNode,
  registerCheckList,
  registerList,
} from "@lexical/list";
import {
  $convertFromMarkdownString,
  $convertToMarkdownString,
  CODE,
  registerMarkdownShortcuts,
  type Transformer,
  TRANSFORMERS,
} from "@lexical/markdown";
import { $setBlocksType } from "@lexical/selection";
import {
  $createHeadingNode,
  $createQuoteNode,
  HeadingNode,
  QuoteNode,
  registerRichText,
  type HeadingTagType,
} from "@lexical/rich-text";
import {
  $createParagraphNode,
  $getSelection,
  $isRangeSelection,
  FORMAT_TEXT_COMMAND,
  createEditor,
  type ElementNode,
  type LexicalEditor,
} from "lexical";

type LexicalHook = {
  el: HTMLElement;
  editor?: LexicalEditor;
  toolbar?: HTMLDivElement;
  unregister?: () => void;
  root?: HTMLDivElement;
  textarea?: HTMLTextAreaElement;
};

const markdownTransformers: Transformer[] = TRANSFORMERS.filter((transformer) => transformer !== CODE);

function textareaFor(editor: HTMLElement): HTMLTextAreaElement | undefined {
  const textareaId = editor.dataset.textareaId;
  if (!textareaId) return undefined;

  const element = document.getElementById(textareaId);
  if (element instanceof HTMLTextAreaElement) return element;

  return undefined;
}

function dispatchTextareaInput(textarea: HTMLTextAreaElement, value: string): void {
  textarea.value = value;
  textarea.dispatchEvent(new Event("input", { bubbles: true }));
}

function button(label: string, title: string, onClick: () => void): HTMLButtonElement {
  const element = document.createElement("button");
  element.type = "button";
  element.className = "LEXICAL_TOOLBAR_BUTTON";
  element.title = title;
  element.textContent = label;

  element.addEventListener("mousedown", (event) => event.preventDefault());
  element.addEventListener("click", onClick);

  return element;
}

function setBlockType(editor: LexicalEditor, createNode: () => ElementNode) {
  editor.update(() => {
    const selection = $getSelection();
    if ($isRangeSelection(selection)) {
      $setBlocksType(selection, createNode);
    }
  });
}

function headingButton(editor: LexicalEditor, tag: HeadingTagType): HTMLButtonElement {
  return button(tag.toUpperCase(), `Heading ${tag.slice(1)}`, () => {
    setBlockType(editor, () => $createHeadingNode(tag));
  });
}

function toolbarFor(editor: LexicalEditor): HTMLDivElement {
  const toolbar = document.createElement("div");
  toolbar.className = "LEXICAL_TOOLBAR";

  toolbar.append(
    button("P", "Paragraph", () => setBlockType(editor, () => $createParagraphNode())),
    headingButton(editor, "h1"),
    headingButton(editor, "h2"),
    headingButton(editor, "h3"),
    button("Quote", "Quote", () => setBlockType(editor, () => $createQuoteNode())),
    button("B", "Bold", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "bold")),
    button("I", "Italic", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "italic")),
    button("Code", "Inline code", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "code")),
    button("Bullets", "Bullet list", () =>
      editor.dispatchCommand(INSERT_UNORDERED_LIST_COMMAND, undefined),
    ),
    button("Numbers", "Numbered list", () =>
      editor.dispatchCommand(INSERT_ORDERED_LIST_COMMAND, undefined),
    ),
    button("Todo", "Task list", () => editor.dispatchCommand(INSERT_CHECK_LIST_COMMAND, undefined)),
    button("Link", "Add link", () => {
      const url = window.prompt("Link URL");
      if (url) editor.update(() => $toggleLink(url));
    }),
    button("Unlink", "Remove link", () => editor.update(() => $toggleLink(null))),
  );

  return toolbar;
}

export const Lexical = {
  mounted(this: LexicalHook) {
    this.textarea = textareaFor(this.el);
    this.root = document.createElement("div");
    this.root.className = "LEXICAL_EDITOR";
    this.root.contentEditable = "true";
    this.root.role = "textbox";
    this.root.ariaMultiLine = "true";
    this.el.appendChild(this.root);

    const editor = createEditor({
      namespace: "WikMarkdownEditor",
      nodes: [HeadingNode, QuoteNode, ListNode, ListItemNode, LinkNode],
      onError(error) {
        throw error;
      },
    });

    editor.setRootElement(this.root);
    this.editor = editor;
    this.toolbar = toolbarFor(editor);
    this.el.prepend(this.toolbar);

    const unregisters = [
      registerRichText(editor),
      registerList(editor),
      registerCheckList(editor),
      registerHistory(editor, createEmptyHistoryState(), 300),
      registerMarkdownShortcuts(editor, markdownTransformers),
      editor.registerUpdateListener(({ editorState }) => {
        if (!this.textarea) return;

        editorState.read(() => {
          dispatchTextareaInput(this.textarea!, $convertToMarkdownString(markdownTransformers));
        });
      }),
    ];

    this.unregister = () => {
      unregisters
        .slice()
        .reverse()
        .forEach((unregister) => unregister());
    };

    editor.update(() => {
      $convertFromMarkdownString(this.textarea?.value || "", markdownTransformers);
    });

    requestAnimationFrame(() => this.root?.focus());
  },

  destroyed(this: LexicalHook) {
    this.unregister?.();
    this.editor?.setRootElement(null);
    this.toolbar?.remove();
    this.root?.remove();
  },
};
