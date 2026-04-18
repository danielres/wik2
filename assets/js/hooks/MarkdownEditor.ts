import { EditorView, minimalSetup } from "codemirror";
import { markdown } from "@codemirror/lang-markdown";
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { tags } from "@lezer/highlight";

type MarkdownEditorHook = {
  el: HTMLElement;
  textarea?: HTMLTextAreaElement;
  view?: EditorView;
};

function textareaFor(editor: HTMLElement): HTMLTextAreaElement | undefined {
  const textareaId = editor.dataset.textareaId;
  if (!textareaId) return undefined;

  const element = document.getElementById(textareaId);
  if (element instanceof HTMLTextAreaElement) return element;

  return undefined;
}

const markdownHighlightStyle = HighlightStyle.define([
  {
    tag: [
      tags.heading,
      tags.heading1,
      tags.heading2,
      tags.heading3,
      tags.heading4,
      tags.heading5,
      tags.heading6,
    ],
    color: "currentColor",
    fontWeight: "700",
    fontSize: "1.25em",
  },
  {
    tag: [tags.list, tags.processingInstruction, tags.punctuation],
    color: "currentColor",
    opacity: "0.9",
  },
]);

export const MarkdownEditor = {
  mounted(this: MarkdownEditorHook) {
    this.textarea = textareaFor(this.el);

    this.view = new EditorView({
      doc: this.textarea?.value || "",
      extensions: [
        minimalSetup,
        syntaxHighlighting(markdownHighlightStyle),
        markdown(),
        EditorView.lineWrapping,
        EditorView.updateListener.of((update) => {
          if (!update.docChanged || !this.textarea) return;

          this.textarea.value = update.state.doc.toString();
          this.textarea.dispatchEvent(new Event("input", { bubbles: true }));
        }),
        EditorView.theme({
          "&": {
            minHeight: "4rem",
          },
          ".cm-cursor, .cm-dropCursor": {
            borderLeftColor: "currentColor",
            borderLeftWidth: "2px",
          },
          ".cm-selectionCursor": {
            borderLeftColor: "currentColor",
          },
        }),
      ],
      parent: this.el,
    });
  },

  destroyed(this: MarkdownEditorHook) {
    this.view?.destroy();
  },
};
