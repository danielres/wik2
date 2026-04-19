import { EditorSelection, StateField, type EditorState } from "@codemirror/state";
import { EditorView, showTooltip, type Tooltip } from "@codemirror/view";

type MarkdownToggle = {
  action: "bold" | "italic" | "strikethrough" | "wikilink";
  open: string;
  close: string;
  title: string;
};

const markdownToggles: readonly MarkdownToggle[] = [
  { action: "bold", open: "**", close: "**", title: "Bold" },
  { action: "italic", open: "_", close: "_", title: "Italic" },
  { action: "strikethrough", open: "~~", close: "~~", title: "Strikethrough" },
  { action: "wikilink", open: "[[", close: "]]", title: "Wikilink" },
];

function toggleMarkdownSelection(
  view: EditorView,
  open: string,
  close: string,
): void {
  const range = view.state.selection.main;
  if (range.empty) return;

  const selectedText = view.state.sliceDoc(range.from, range.to);
  const alreadyWrapped = selectedText.startsWith(open) && selectedText.endsWith(close);

  const nextText = alreadyWrapped
    ? selectedText.slice(open.length, selectedText.length - close.length)
    : `${open}${selectedText}${close}`;

  view.dispatch({
    changes: { from: range.from, to: range.to, insert: nextText },
    selection: EditorSelection.range(range.from, range.from + nextText.length),
    scrollIntoView: true,
  });

  view.focus();
}

function markdownSelectionToolbarTooltip(state: EditorState): Tooltip | null {
  const range = state.selection.main;
  if (range.empty) return null;

  return {
    pos: range.from,
    end: range.to,
    above: true,
    strictSide: true,
    create(view) {
      const dom = document.createElement("div");
      dom.className = "cm-markdown-selection-toolbar";

      for (const toggle of markdownToggles) {
        const button = document.createElement("button");
        button.className = "cm-markdown-selection-toolbar-button";
        button.type = "button";
        button.title = toggle.title;
        button.ariaLabel = toggle.title;
        button.dataset.markdownAction = toggle.action;
        button.addEventListener("mousedown", (event) => event.preventDefault());
        button.addEventListener("click", (event) => {
          event.preventDefault();
          toggleMarkdownSelection(view, toggle.open, toggle.close);
        });
        dom.append(button);
      }

      return { dom };
    },
  };
}

export function markdownSelectionToolbar() {
  return StateField.define<Tooltip | null>({
    create(state) {
      return markdownSelectionToolbarTooltip(state);
    },
    update(_tooltip, transaction) {
      return markdownSelectionToolbarTooltip(transaction.state);
    },
    provide(field) {
      return showTooltip.from(field);
    },
  });
}
