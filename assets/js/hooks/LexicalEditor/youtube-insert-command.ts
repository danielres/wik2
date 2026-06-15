import {
  $createParagraphNode,
  $getNodeByKey,
  COMMAND_PRIORITY_LOW,
  createCommand,
  type LexicalCommand,
  type LexicalEditor,
  type NodeKey,
} from "lexical";

import { $createYouTubeNode } from "./youtube";

type InsertYouTubePayload = {
  afterKey: NodeKey;
  videoId: string;
};

export const INSERT_YOUTUBE_COMMAND: LexicalCommand<InsertYouTubePayload> = createCommand(
  "INSERT_YOUTUBE_COMMAND",
);

export function registerYouTubeInsert(editor: LexicalEditor): () => void {
  return editor.registerCommand(
    INSERT_YOUTUBE_COMMAND,
    ({ afterKey, videoId }) => {
      const targetNode = $getNodeByKey(afterKey);
      if (!targetNode) return true;

      const node = $createYouTubeNode(videoId);
      const paragraph = $createParagraphNode();
      targetNode.insertAfter(node);
      node.insertAfter(paragraph);
      paragraph.selectStart();

      return true;
    },
    COMMAND_PRIORITY_LOW,
  );
}
