import {
  autocompletion,
  closeBrackets,
  closeBracketsKeymap,
  completionKeymap,
} from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { markdown } from "@codemirror/lang-markdown";
import {
  bracketMatching,
  defaultHighlightStyle,
  indentOnInput,
  syntaxHighlighting,
} from "@codemirror/language";
import { highlightSelectionMatches, searchKeymap } from "@codemirror/search";
import { EditorState } from "@codemirror/state";
import {
  crosshairCursor,
  drawSelection,
  dropCursor,
  EditorView,
  highlightActiveLine,
  highlightSpecialChars,
  keymap,
  rectangularSelection,
} from "@codemirror/view";

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
        highlightSpecialChars(),
        history(),
        drawSelection(),
        dropCursor(),
        EditorState.allowMultipleSelections.of(true),
        indentOnInput(),
        syntaxHighlighting(defaultHighlightStyle, { fallback: true }),
        bracketMatching(),
        closeBrackets(),
        autocompletion(),
        rectangularSelection(),
        crosshairCursor(),
        highlightActiveLine(),
        highlightSelectionMatches(),
        keymap.of([
          ...closeBracketsKeymap,
          ...defaultKeymap,
          ...searchKeymap,
          ...historyKeymap,
          ...completionKeymap,
        ]),
        markdown(),
        EditorView.lineWrapping,
        EditorView.updateListener.of((update) => {
          if (!update.docChanged || !this.textarea) return;

          this.textarea.value = update.state.doc.toString();
          this.textarea.dispatchEvent(new Event("input", { bubbles: true }));
        }),
        EditorView.theme({
          "&": {
            minHeight: "12rem",
          },
          ".cm-content": {
            fontFamily:
              "ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace",
          },
          ".cm-scroller": {
            minHeight: "12rem",
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
