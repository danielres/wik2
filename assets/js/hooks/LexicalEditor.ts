import { createEmptyHistoryState, registerHistory } from "@lexical/history";
import { LinkNode } from "@lexical/link";
import { ListItemNode, ListNode, registerCheckList, registerList } from "@lexical/list";
import {
  $convertFromMarkdownString,
  $convertToMarkdownString,
  registerMarkdownShortcuts,
} from "@lexical/markdown";
import { HeadingNode, QuoteNode, registerRichText } from "@lexical/rich-text";
import {
  $getNodeByKey,
  SELECTION_CHANGE_COMMAND,
  COMMAND_PRIORITY_LOW,
  createEditor,
  type LexicalEditor,
  type NodeKey,
} from "lexical";

import { createBlockControls, type BlockControls } from "./LexicalEditor/block-controls";
import { markdownTransformers, normalizeExportedMarkdown, preserveNewLines } from "./LexicalEditor/markdown";
import { floatingToolbarFor, toolbarFor, updateFloatingToolbar } from "./LexicalEditor/toolbar";
import { $createYouTubeNode, YouTubeNode } from "./LexicalEditor/youtube";
import { openYoutubeDialog, youtubeDialogFor } from "./LexicalEditor/youtube-dialog";

type LexicalHook = {
  blockControls?: BlockControls;
  editor?: LexicalEditor;
  el: HTMLElement;
  floatingToolbar?: HTMLDivElement;
  pendingYoutubeInsertKey?: NodeKey;
  root?: HTMLDivElement;
  textarea?: HTMLTextAreaElement;
  toolbar?: HTMLDivElement;
  unregister?: () => void;
  youtubeDialog?: HTMLDialogElement;
};

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

function createMarkdownEditor(): LexicalEditor {
  return createEditor({
    namespace: "WikMarkdownEditor",
    nodes: [HeadingNode, QuoteNode, ListNode, ListItemNode, LinkNode, YouTubeNode],
    onError(error) {
      throw error;
    },
  });
}

export const LexicalEditor = {
  mounted(this: LexicalHook) {
    this.textarea = textareaFor(this.el);
    this.root = document.createElement("div");
    this.root.className = "LEXICAL_EDITOR";
    this.root.contentEditable = "true";
    this.root.role = "textbox";
    this.root.ariaMultiLine = "true";
    this.el.appendChild(this.root);

    const editor = createMarkdownEditor();
    editor.setRootElement(this.root);
    this.editor = editor;

    const insertYouTubeNode = (key: NodeKey, videoId: string) => {
      editor.update(() => {
        const targetNode = $getNodeByKey(key);
        if (!targetNode) return;

        targetNode.insertAfter($createYouTubeNode(videoId));
      });
    };

    this.toolbar = toolbarFor(editor);
    this.floatingToolbar = floatingToolbarFor(editor);
    this.youtubeDialog = youtubeDialogFor(
      (videoId) => {
        const key = this.pendingYoutubeInsertKey;
        this.pendingYoutubeInsertKey = undefined;
        if (!key) return;

        insertYouTubeNode(key, videoId);
        this.blockControls?.hide();
      },
      () => {
        this.pendingYoutubeInsertKey = undefined;
      },
    );
    this.blockControls = createBlockControls({
      editor,
      root: this.root,
      onYoutubeEmbed: (key) => {
        this.pendingYoutubeInsertKey = key;
        if (this.youtubeDialog) openYoutubeDialog(this.youtubeDialog);
      },
    });

    this.el.prepend(this.toolbar);
    document.body.appendChild(this.floatingToolbar);
    document.body.append(
      this.blockControls.insertButton,
      this.blockControls.dragHandle,
      this.blockControls.insertMenu,
      this.blockControls.dropIndicator,
      this.youtubeDialog,
    );

    const updateFloating = () => {
      if (this.root && this.floatingToolbar) {
        updateFloatingToolbar(editor, this.root, this.floatingToolbar);
      }
    };

    const unregisters = [
      registerRichText(editor),
      registerList(editor),
      registerCheckList(editor),
      registerHistory(editor, createEmptyHistoryState(), 300),
      registerMarkdownShortcuts(editor, markdownTransformers),
      editor.registerUpdateListener(({ editorState }) => {
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
      }),
      editor.registerCommand(
        SELECTION_CHANGE_COMMAND,
        () => {
          updateFloating();
          return false;
        },
        COMMAND_PRIORITY_LOW,
      ),
      () => window.removeEventListener("resize", updateFloating),
      () => window.removeEventListener("scroll", updateFloating, true),
      () => this.blockControls?.unregister(),
    ];

    window.addEventListener("resize", updateFloating);
    window.addEventListener("scroll", updateFloating, true);

    this.unregister = () => {
      unregisters
        .slice()
        .reverse()
        .forEach((unregister) => unregister());
    };

    editor.update(() => {
      $convertFromMarkdownString(
        this.textarea?.value || "",
        markdownTransformers,
        undefined,
        preserveNewLines,
      );
    });

    requestAnimationFrame(() => this.root?.focus());
  },

  destroyed(this: LexicalHook) {
    this.unregister?.();
    this.editor?.setRootElement(null);
    this.blockControls?.insertButton.remove();
    this.blockControls?.insertMenu.remove();
    this.youtubeDialog?.remove();
    this.blockControls?.dragHandle.remove();
    this.blockControls?.dropIndicator.remove();
    this.floatingToolbar?.remove();
    this.toolbar?.remove();
    this.root?.remove();
  },
};
