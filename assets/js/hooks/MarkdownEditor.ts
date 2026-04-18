import { EditorView, minimalSetup } from "codemirror";
import { markdown } from "@codemirror/lang-markdown";

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

export const MarkdownEditor = {
  mounted(this: MarkdownEditorHook) {
    this.textarea = textareaFor(this.el);

    this.view = new EditorView({
      doc: this.textarea?.value || "",
      extensions: [
        minimalSetup,
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
          ".cm-content": {
          },
          ".cm-scroller": {
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
