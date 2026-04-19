import {
  EditorSelection,
  StateEffect,
  StateField,
  type Extension,
  type EditorState,
} from "@codemirror/state";
import { EditorView, keymap, showTooltip, type Tooltip } from "@codemirror/view";

type MarkdownToggle = {
  action: "bold" | "italic" | "strikethrough" | "wikilink" | "external-link";
  open: string;
  close: string;
  title: string;
};

type ExternalLinkRange = {
  from: number;
  to: number;
};

type ToolbarState =
  | { mode: "toolbar"; range: ExternalLinkRange }
  | { mode: "external-link"; range: ExternalLinkRange }
  | null;

const markdownToggles: readonly MarkdownToggle[] = [
  { action: "bold", open: "**", close: "**", title: "Bold" },
  { action: "italic", open: "_", close: "_", title: "Italic" },
  { action: "strikethrough", open: "~~", close: "~~", title: "Strikethrough" },
  { action: "wikilink", open: "[[", close: "]]", title: "Wikilink" },
  { action: "external-link", open: "", close: "", title: "External link" },
];

const openExternalLinkForm = StateEffect.define<ExternalLinkRange>();
const closeExternalLinkForm = StateEffect.define();

function closeExternalLinkTooltip(view: EditorView): void {
  view.dispatch({ effects: closeExternalLinkForm.of(null) });
  view.focus();
}

function defaultToolbarState(state: EditorState): ToolbarState {
  const range = state.selection.main;
  return range.empty ? null : { mode: "toolbar", range: { from: range.from, to: range.to } };
}

function toggleExternalLinkForm(view: EditorView): void {
  const range = view.state.selection.main;
  if (range.empty) return;

  view.dispatch({
    effects: openExternalLinkForm.of({ from: range.from, to: range.to }),
  });
}

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

function insertExternalLink(
  view: EditorView,
  range: ExternalLinkRange,
  url: string,
): void {
  const trimmedUrl = url.trim();

  if (trimmedUrl == "") {
    closeExternalLinkTooltip(view);
    return;
  }

  const selectedText = view.state.sliceDoc(range.from, range.to);
  const nextText = `[${selectedText}](${trimmedUrl})`;

  view.dispatch({
    changes: { from: range.from, to: range.to, insert: nextText },
    effects: closeExternalLinkForm.of(null),
    selection: EditorSelection.range(range.from, range.from + nextText.length),
    scrollIntoView: true,
  });

  view.focus();
}

function externalLinkTooltip(range: ExternalLinkRange): Tooltip {
  return {
    pos: range.from,
    end: range.to,
    above: true,
    strictSide: true,
    create(view) {
      const form = document.createElement("form");
      form.className = "cm-markdown-external-link-form";

      const input = document.createElement("input");
      input.className = "cm-markdown-external-link-input";
      input.type = "url";
      input.placeholder = "https://example.com";
      input.ariaLabel = "External link URL";

      const submitButton = document.createElement("button");
      submitButton.className = "cm-markdown-external-link-submit";
      submitButton.type = "submit";
      submitButton.title = "Apply external link";
      submitButton.ariaLabel = "Apply external link";

      const cancelButton = document.createElement("button");
      cancelButton.className = "cm-markdown-external-link-cancel";
      cancelButton.type = "button";
      cancelButton.title = "Cancel";
      cancelButton.ariaLabel = "Cancel";

      cancelButton.addEventListener("click", (event) => {
        event.preventDefault();
        closeExternalLinkTooltip(view);
      });

      const closeOnEscape = (event: KeyboardEvent) => {
        if (event.key != "Escape") return;

        event.preventDefault();
        event.stopPropagation();
        closeExternalLinkTooltip(view);
      };

      form.addEventListener("keydown", closeOnEscape, { capture: true });

      form.addEventListener("submit", (event) => {
        event.preventDefault();
        insertExternalLink(view, range, input.value);
      });

      form.append(input, submitButton, cancelButton);

      return {
        dom: form,
        mount() {
          window.addEventListener("keydown", closeOnEscape, { capture: true });
          input.focus();
        },
        destroy() {
          window.removeEventListener("keydown", closeOnEscape, { capture: true });
        },
      };
    },
  };
}

function toolbarTooltip(range: ExternalLinkRange): Tooltip {
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

          if (toggle.action == "external-link") {
            toggleExternalLinkForm(view);
          } else {
            toggleMarkdownSelection(view, toggle.open, toggle.close);
          }
        });
        dom.append(button);
      }

      return { dom };
    },
  };
}

function tooltipFor(toolbarState: ToolbarState): Tooltip | null {
  if (toolbarState?.mode == "external-link") {
    return externalLinkTooltip(toolbarState.range);
  }

  if (toolbarState?.mode == "toolbar") {
    return toolbarTooltip(toolbarState.range);
  }

  return null;
}

export function markdownSelectionToolbar() {
  const toolbarState = StateField.define<ToolbarState>({
    create(state) {
      return defaultToolbarState(state);
    },
    update(toolbarState, transaction) {
      let nextToolbarState = toolbarState;
      let forceClosed = false;

      if (nextToolbarState?.mode == "external-link" && transaction.docChanged) {
        const from = transaction.changes.mapPos(nextToolbarState.range.from);
        const to = transaction.changes.mapPos(nextToolbarState.range.to);
        nextToolbarState =
          from < to ? { mode: "external-link", range: { from, to } } : null;
      }

      for (const effect of transaction.effects) {
        if (effect.is(openExternalLinkForm)) {
          nextToolbarState = { mode: "external-link", range: effect.value };
        }

        if (effect.is(closeExternalLinkForm)) {
          forceClosed = true;
          nextToolbarState = null;
        }
      }

      if (forceClosed) return null;

      if (nextToolbarState?.mode == "external-link") return nextToolbarState;

      return defaultToolbarState(transaction.state);
    },
    provide(field) {
      return showTooltip.from(field, tooltipFor);
    },
  });

  return [
    toolbarState,
    keymap.of([
      {
        key: "Escape",
        run(view) {
          if (view.state.field(toolbarState)?.mode != "external-link") return false;

          view.dispatch({ effects: closeExternalLinkForm.of(null) });
          view.focus();
          return true;
        },
      },
    ]),
  ] satisfies Extension;
}
