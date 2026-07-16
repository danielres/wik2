import {
  buildEditorFromExtensions,
  ClickAfterLastBlockExtension,
  configExtension,
  defineExtension,
  TabIndentationExtension,
  type LexicalEditorWithDispose,
} from "@lexical/extension";
import { LinkNode } from "@lexical/link";
import { ListItemNode, ListNode } from "@lexical/list";
import {
  $convertFromMarkdownString,
  $convertToMarkdownString,
} from "@lexical/markdown";
import { HeadingNode, QuoteNode } from "@lexical/rich-text";
import {
  mergeRegister,
  type EditorState,
  type NodeKey,
} from "lexical";

import { markdownEditorBehaviorExtension } from "./LexicalEditor/behavior";
import { createBlockControls, type BlockControls } from "./LexicalEditor/block-controls";
import { createLinkEditor, type LinkEditor } from "./LexicalEditor/link-editor";
import { markdownTransformers, normalizeExportedMarkdown, preserveNewLines } from "./LexicalEditor/markdown";
import {
  floatingToolbarFor,
  toolbarFor,
  updateFloatingToolbar,
  updateToolbarState,
} from "./LexicalEditor/toolbar";
import {
  createWikilinkCompletions,
  parseWikilinkDataset,
  type WikilinkCompletions,
} from "./LexicalEditor/wikilink-completions";
import { $isYouTubeNode, YouTubeNode } from "./LexicalEditor/youtube";
import { openYoutubeDialog, youtubeDialogFor } from "./LexicalEditor/youtube-dialog";
import { INSERT_YOUTUBE_COMMAND } from "./LexicalEditor/youtube-insert-command";

type LexicalHook = {
  blockControls?: BlockControls;
  editor?: LexicalEditorWithDispose;
  el: HTMLElement;
  floatingToolbar?: HTMLDivElement;
  linkEditor?: LinkEditor;
  pendingYoutubeInsertKey?: NodeKey;
  root?: HTMLDivElement;
  textarea?: HTMLTextAreaElement;
  toolbar?: HTMLDivElement;
  unregister?: () => void;
  wikilinkCompletions?: WikilinkCompletions;
  youtubeDialog?: HTMLDialogElement;
};

function requiredDatasetValue(element: HTMLElement, name: string): string {
  const value = element.dataset[name];
  if (!value) throw new Error(`Missing Lexical editor data-${name}`);

  return value;
}

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

const markdownEditorBaseExtension = defineExtension({
  name: "WikMarkdownEditor",
  namespace: "WikMarkdownEditor",
  nodes: [HeadingNode, QuoteNode, ListNode, ListItemNode, LinkNode, YouTubeNode],
  dependencies: [
    configExtension(ClickAfterLastBlockExtension, {
      $shouldInsertAfter: $isYouTubeNode,
    }),
    TabIndentationExtension,
  ],
  onError(error) {
    throw error;
  },
});

type MarkdownEditorOptions = {
  onChange: (editorState: EditorState) => void;
  onSelectionChange: () => void;
};

function createMarkdownEditor(options: MarkdownEditorOptions): LexicalEditorWithDispose {
  return buildEditorFromExtensions(
    markdownEditorBaseExtension,
    markdownEditorBehaviorExtension(options),
  );
}

export const LexicalEditor = {
  mounted(this: LexicalHook) {
    this.textarea = textareaFor(this.el);
    const initialMarkdown = this.textarea?.value || "";
    let syncEditorState = false;

    this.root = document.createElement("div");
    this.root.className = "LEXICAL_EDITOR";
    this.root.contentEditable = "true";
    this.root.role = "textbox";
    this.root.ariaMultiLine = "true";
    this.el.appendChild(this.root);

    let updateFloating = () => { };

    const syncTextarea = (editorState: EditorState) => {
      if (!syncEditorState) return;
      if (!this.textarea) return;

      editorState.read(() => {
        dispatchTextareaInput(
          this.textarea!,
          normalizeExportedMarkdown(
            $convertToMarkdownString(markdownTransformers, undefined, preserveNewLines),
          ),
        );
      });

      updateFloating();
      this.blockControls?.update();
    };

    const editor = createMarkdownEditor({
      onChange: syncTextarea,
      onSelectionChange: () => updateFloating(),
    });
    editor.setRootElement(this.root);
    this.editor = editor;

    this.toolbar = toolbarFor(editor, requiredDatasetValue(this.el, "toolbarTemplateId"));
    this.floatingToolbar = floatingToolbarFor(
      editor,
      requiredDatasetValue(this.el, "floatingToolbarTemplateId"),
    );
    this.linkEditor = createLinkEditor({
      editor,
      root: this.root,
      templateId: requiredDatasetValue(this.el, "linkEditorTemplateId"),
    });
    this.youtubeDialog = youtubeDialogFor(
      requiredDatasetValue(this.el, "youtubeDialogTemplateId"),
      (videoId) => {
        const key = this.pendingYoutubeInsertKey;
        this.pendingYoutubeInsertKey = undefined;
        if (!key) return;

        editor.dispatchCommand(INSERT_YOUTUBE_COMMAND, { afterKey: key, videoId });
        this.blockControls?.hide();
      },
      () => {
        this.pendingYoutubeInsertKey = undefined;
      },
    );
    this.blockControls = createBlockControls({
      editor,
      insertMenuTemplateId: requiredDatasetValue(this.el, "insertMenuTemplateId"),
      root: this.root,
      onYoutubeEmbed: (key) => {
        this.pendingYoutubeInsertKey = key;
        if (this.youtubeDialog) openYoutubeDialog(this.youtubeDialog);
      },
    });
    this.wikilinkCompletions = createWikilinkCompletions({
      editor,
      root: this.root,
      templateId: requiredDatasetValue(this.el, "wikilinkCompletionMenuTemplateId"),
      wikilinkPaths: parseWikilinkDataset(this.el, "wikilinkPaths"),
      wikilinkTagNames: parseWikilinkDataset(this.el, "tagWikilinkNames"),
      wikilinkUsernames: parseWikilinkDataset(this.el, "memberWikilinkUsernames"),
    });

    this.el.prepend(this.toolbar);
    document.body.appendChild(this.floatingToolbar);
    document.body.append(
      this.linkEditor.element,
      this.blockControls.dragHandle,
      this.blockControls.insertMenu,
      this.blockControls.dropIndicator,
      this.wikilinkCompletions.menu,
      this.youtubeDialog,
    );

    updateFloating = () => {
      if (this.toolbar) {
        updateToolbarState(editor, this.toolbar);
      }

      if (this.root && this.floatingToolbar) {
        updateFloatingToolbar(editor, this.root, this.floatingToolbar);
      }
      this.linkEditor?.update();
      this.wikilinkCompletions?.update();
    };

    window.addEventListener("resize", updateFloating);
    window.addEventListener("scroll", updateFloating, true);

    this.unregister = mergeRegister(
      () => window.removeEventListener("resize", updateFloating),
      () => window.removeEventListener("scroll", updateFloating, true),
      () => this.blockControls?.unregister(),
      () => this.linkEditor?.unregister(),
      () => this.wikilinkCompletions?.unregister(),
    );

    editor.update(() => {
      $convertFromMarkdownString(
        initialMarkdown,
        markdownTransformers,
        undefined,
        preserveNewLines,
      );
    });
    syncEditorState = true;
    updateFloating();
    this.blockControls.update();

    requestAnimationFrame(() => this.root?.focus());
  },

  destroyed(this: LexicalHook) {
    this.unregister?.();
    this.editor?.dispose();
    this.blockControls?.insertMenu.remove();
    this.linkEditor?.element.remove();
    this.wikilinkCompletions?.menu.remove();
    this.youtubeDialog?.remove();
    this.blockControls?.dragHandle.remove();
    this.blockControls?.dropIndicator.remove();
    this.floatingToolbar?.remove();
    this.toolbar?.remove();
    this.root?.remove();
  },
};
