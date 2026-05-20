import {
  autocompletion,
  type Completion,
  type CompletionContext,
  type CompletionResult,
} from "@codemirror/autocomplete";
import { defaultKeymap, history, historyKeymap } from "@codemirror/commands";
import { markdown } from "@codemirror/lang-markdown";
import { HighlightStyle, syntaxHighlighting } from "@codemirror/language";
import { EditorView, highlightSpecialChars, keymap } from "@codemirror/view";
import { styleTags, Tag, tags } from "@lezer/highlight";
import { pasteHtmlAsMarkdown } from "./MarkdownEditor/pasteHtmlAsMarkdown";
import { markdownSelectionToolbar } from "./MarkdownEditor/selectionToolbar";

type MarkdownEditorHook = {
  el: HTMLElement;
  wikilinkMemberCompletions?: readonly Completion[];
  textarea?: HTMLTextAreaElement;
  view?: EditorView;
  wikilinkCompletions?: readonly Completion[];
};

function textareaFor(editor: HTMLElement): HTMLTextAreaElement | undefined {
  const textareaId = editor.dataset.textareaId;
  if (!textareaId) return undefined;

  const element = document.getElementById(textareaId);
  if (element instanceof HTMLTextAreaElement) return element;

  return undefined;
}

function wikilinkCompletionsFor(editor: HTMLElement): readonly Completion[] {
  const paths = JSON.parse(editor.dataset.wikilinkPaths || "[]") as string[];

  return paths.map((path) => ({
    label: path,
    apply: `${path}]]`,
    type: "text",
  }));
}

function wikilinkMemberCompletionsFor(editor: HTMLElement): readonly Completion[] {
  const usernames = JSON.parse(editor.dataset.memberWikilinkUsernames || "[]") as string[];

  return usernames.map((username) => ({
    label: `@${username}`,
    apply: `@${username}]]`,
    type: "text",
  }));
}

function wikilinkCompletionSource(
  completions: readonly Completion[],
): (context: CompletionContext) => CompletionResult | null {
  return (context: CompletionContext): CompletionResult | null => {
    const before = context.matchBefore(/\[\[[^\]\n]*$/);
    if (!before || before.text.startsWith("[[@")) return null;

    return {
      from: before.from + 2,
      to: context.pos,
      options: completions,
      validFor: /^[^\]\n]*$/,
    };
  };
}

function memberWikilinkCompletionSource(
  completions: readonly Completion[],
): (context: CompletionContext) => CompletionResult | null {
  return (context: CompletionContext): CompletionResult | null => {
    const before = context.matchBefore(/\[\[@[^\]\n]*$/);
    if (!before) return null;

    return {
      from: before.from + 2,
      to: context.pos,
      options: completions,
      validFor: /^@[^\]\n]*$/,
    };
  };
}

const markdownHeaderMark = Tag.define();

const markdownSyntaxHighlighting = {
  props: [
    styleTags({
      HeaderMark: markdownHeaderMark,
    }),
  ],
};

const markdownHighlightStyle = HighlightStyle.define([
  {
    tag: [tags.heading, tags.heading4, tags.heading5, tags.heading6],
    color: "currentColor",
    fontWeight: "700",
  },
  {
    tag: tags.heading1,
    color: "currentColor",
    fontSize: "var(--text-2xl)",
    fontWeight: "700",
    lineHeight: "var(--text-2xl--line-height)",
  },
  {
    tag: tags.heading2,
    color: "currentColor",
    fontSize: "var(--text-xl)",
    fontWeight: "700",
    lineHeight: "var(--text-xl--line-height)",
  },
  {
    tag: tags.heading3,
    color: "currentColor",
    fontSize: "var(--text-lg)",
    fontWeight: "700",
    lineHeight: "var(--text-lg--line-height)",
  },
  {
    tag: markdownHeaderMark,
    opacity: "0.4",
  },
]);

export const MarkdownEditor = {
  mounted(this: MarkdownEditorHook) {
    this.textarea = textareaFor(this.el);
    this.wikilinkMemberCompletions = wikilinkMemberCompletionsFor(this.el);
    this.wikilinkCompletions = wikilinkCompletionsFor(this.el);

    this.view = new EditorView({
      doc: this.textarea?.value || "",
      extensions: [
        highlightSpecialChars(),
        history(),
        keymap.of([...defaultKeymap, ...historyKeymap]),
        syntaxHighlighting(markdownHighlightStyle),
        markdown({ extensions: markdownSyntaxHighlighting }),
        pasteHtmlAsMarkdown(),
        markdownSelectionToolbar(),
        autocompletion({
          override: [
            memberWikilinkCompletionSource(this.wikilinkMemberCompletions),
            wikilinkCompletionSource(this.wikilinkCompletions),
          ],
          icons: false,
          closeOnBlur: false,
        }),
        EditorView.lineWrapping,
        EditorView.updateListener.of((update) => {
          if (!update.docChanged || !this.textarea) return;

          this.textarea.value = update.state.doc.toString();
          this.textarea.dispatchEvent(new Event("input", { bubbles: true }));
        }),
      ],
      parent: this.el,
    });

    requestAnimationFrame(() => this.view?.focus());
  },

  destroyed(this: MarkdownEditorHook) {
    this.view?.destroy();
  },
};
