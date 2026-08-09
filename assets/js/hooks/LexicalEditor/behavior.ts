import { $isListItemNode } from "@lexical/list";
import { registerMarkdownShortcuts } from "@lexical/markdown";
import {
  $getSelection,
  $isRangeSelection,
  COMMAND_PRIORITY_HIGH,
  COMMAND_PRIORITY_LOW,
  defineExtension,
  INDENT_CONTENT_COMMAND,
  KEY_TAB_COMMAND,
  mergeRegister,
  OUTDENT_CONTENT_COMMAND,
  SELECTION_CHANGE_COMMAND,
  type EditorState,
  type LexicalEditor,
  type LexicalNode,
} from "lexical";

import { markdownTransformers } from "./markdown";
import { registerYouTubeEditing } from "./youtube-editor";
import { registerYouTubeInsert } from "./youtube-insert-command";

type MarkdownEditorBehaviorOptions = {
  onChange: (editorState: EditorState) => void;
  onSelectionChange: () => void;
};

function nodeIsInListItem(node: LexicalNode): boolean {
  let current: LexicalNode | null = node;

  while (current) {
    if ($isListItemNode(current)) return true;

    current = current.getParent();
  }

  return false;
}

function selectionTouchesListItem(): boolean {
  const selection = $getSelection();
  if (!$isRangeSelection(selection)) return false;

  return selection.getNodes().some(nodeIsInListItem);
}

function registerListTabIndent(editor: LexicalEditor): () => void {
  return editor.registerCommand(
    KEY_TAB_COMMAND,
    (event) => {
      if (!selectionTouchesListItem()) return false;

      event.preventDefault();

      return editor.dispatchCommand(
        event.shiftKey ? OUTDENT_CONTENT_COMMAND : INDENT_CONTENT_COMMAND,
        undefined,
      );
    },
    COMMAND_PRIORITY_HIGH,
  );
}

export function markdownEditorBehaviorExtension({
  onChange,
  onSelectionChange,
}: MarkdownEditorBehaviorOptions) {
  return defineExtension({
    name: "WikMarkdownEditorBehavior",
    register(editor: LexicalEditor) {
      return mergeRegister(
        registerListTabIndent(editor),
        registerMarkdownShortcuts(editor, markdownTransformers),
        registerYouTubeInsert(editor),
        registerYouTubeEditing(editor),
        editor.registerUpdateListener(({ dirtyElements, dirtyLeaves, editorState }) => {
          if (dirtyElements.size === 0 && dirtyLeaves.size === 0) return;

          onChange(editorState);
        }),
        editor.registerCommand(
          SELECTION_CHANGE_COMMAND,
          () => {
            onSelectionChange();
            return false;
          },
          COMMAND_PRIORITY_LOW,
        ),
      );
    },
  });
}
