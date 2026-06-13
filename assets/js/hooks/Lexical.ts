import { createEmptyHistoryState, registerHistory } from "@lexical/history";
import { LinkNode } from "@lexical/link";
import { ListItemNode, ListNode, registerCheckList, registerList } from "@lexical/list";
import {
  $convertFromMarkdownString,
  $convertToMarkdownString,
  CODE,
  registerMarkdownShortcuts,
  type Transformer,
  TRANSFORMERS,
} from "@lexical/markdown";
import { HeadingNode, QuoteNode, registerRichText } from "@lexical/rich-text";
import { createEditor, type LexicalEditor } from "lexical";

type LexicalHook = {
  el: HTMLElement;
  editor?: LexicalEditor;
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
    this.root?.remove();
  },
};
