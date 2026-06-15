import { createEmptyHistoryState, registerHistory } from "@lexical/history";
import { registerCheckList, registerList } from "@lexical/list";
import { registerMarkdownShortcuts } from "@lexical/markdown";
import { registerRichText } from "@lexical/rich-text";
import {
  COMMAND_PRIORITY_LOW,
  defineExtension,
  mergeRegister,
  SELECTION_CHANGE_COMMAND,
  type EditorState,
  type LexicalEditor,
} from "lexical";

import { markdownTransformers } from "./markdown";
import { registerYouTubeEditing } from "./youtube-editor";
import { registerYouTubeInsert } from "./youtube-insert-command";

type MarkdownEditorBehaviorOptions = {
  onChange: (editorState: EditorState) => void;
  onSelectionChange: () => void;
};

export function markdownEditorBehaviorExtension({
  onChange,
  onSelectionChange,
}: MarkdownEditorBehaviorOptions) {
  return defineExtension({
    name: "WikMarkdownEditorBehavior",
    register(editor: LexicalEditor) {
      return mergeRegister(
        registerRichText(editor),
        registerList(editor),
        registerCheckList(editor),
        registerHistory(editor, createEmptyHistoryState(), 300),
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
