import {
  $createParagraphNode,
  $createNodeSelection,
  $getNodeByKey,
  $getSelection,
  $isNodeSelection,
  $setSelection,
  CLICK_COMMAND,
  COMMAND_PRIORITY_HIGH,
  COMMAND_PRIORITY_LOW,
  KEY_BACKSPACE_COMMAND,
  KEY_DELETE_COMMAND,
  KEY_ENTER_COMMAND,
  SELECTION_CHANGE_COMMAND,
  type LexicalEditor,
  type LexicalNode,
  type NodeKey,
} from "lexical";
import { $isYouTubeNode } from "./youtube";

function youtubeKeyFromEvent(event: MouseEvent): NodeKey | undefined {
  const target = event.target instanceof Element ? event.target : undefined;
  const embed = target?.closest("[data-lexical-youtube-key]");

  return embed instanceof HTMLElement ? embed.dataset.lexicalYoutubeKey : undefined;
}

function youtubeEmbedFromEvent(event: MouseEvent): HTMLElement | undefined {
  const target = event.target instanceof Element ? event.target : undefined;
  const embed = target?.closest("[data-lexical-youtube-key]");

  return embed instanceof HTMLElement ? embed : undefined;
}

function selectYouTubeNode(key: NodeKey): void {
  const selection = $createNodeSelection();
  selection.add(key);
  $setSelection(selection);
}

function selectedYouTubeNodesForDelete(): LexicalNode[] {
  const selection = $getSelection();
  if (!$isNodeSelection(selection)) return [];

  return selection.getNodes().filter($isYouTubeNode);
}

function selectedYouTubeNodesForStyle(): LexicalNode[] {
  const selection = $getSelection();
  if (!selection) return [];

  return selection.getNodes().filter($isYouTubeNode);
}

function deleteSelectedYouTubeNodes(): boolean {
  const nodes = selectedYouTubeNodesForDelete();
  if (nodes.length === 0) return false;

  nodes.forEach((node) => node.remove());
  return true;
}

function insertParagraphAfterSelectedYouTube(): boolean {
  const selection = $getSelection();
  if (!$isNodeSelection(selection)) return false;

  const node = selection.getNodes().find($isYouTubeNode);
  if (!node) return false;

  const paragraph = $createParagraphNode();
  node.insertAfter(paragraph);
  paragraph.selectStart();
  return true;
}

function syncSelectedClass(editor: LexicalEditor): void {
  const root = editor.getRootElement();
  if (!root) return;

  const selectedKeys = new Set<NodeKey>();

  editor.getEditorState().read(() => {
    selectedYouTubeNodesForStyle().forEach((node) => selectedKeys.add(node.getKey()));
  });

  root.querySelectorAll("[data-lexical-youtube-key]").forEach((element) => {
    if (!(element instanceof HTMLElement)) return;

    const key = element.dataset.lexicalYoutubeKey;
    element.classList.toggle("selected", !!key && selectedKeys.has(key));
  });
}

export function registerYouTubeEditing(editor: LexicalEditor): () => void {
  let syncScheduled = false;

  const scheduleSyncSelectedClass = () => {
    if (syncScheduled) return;

    syncScheduled = true;
    requestAnimationFrame(() => {
      syncScheduled = false;
      syncSelectedClass(editor);
    });
  };

  const unregisters = [
    editor.registerCommand(
      CLICK_COMMAND,
      (event) => {
        const embed = youtubeEmbedFromEvent(event);
        const key = youtubeKeyFromEvent(event);
        if (!key) return false;

        const node = $getNodeByKey(key);
        if (!$isYouTubeNode(node)) return false;

        selectYouTubeNode(key);
        embed?.classList.add("selected");
        scheduleSyncSelectedClass();

        event.preventDefault();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
    editor.registerCommand(
      KEY_BACKSPACE_COMMAND,
      (event) => {
        if (!deleteSelectedYouTubeNodes()) return false;

        event.preventDefault();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
    editor.registerCommand(
      KEY_DELETE_COMMAND,
      (event) => {
        if (!deleteSelectedYouTubeNodes()) return false;

        event.preventDefault();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
    editor.registerCommand(
      KEY_ENTER_COMMAND,
      (event) => {
        if (!insertParagraphAfterSelectedYouTube()) return false;

        event?.preventDefault();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
    editor.registerUpdateListener(() => {
      scheduleSyncSelectedClass();
    }),
    editor.registerCommand(
      SELECTION_CHANGE_COMMAND,
      () => {
        scheduleSyncSelectedClass();
        return false;
      },
      COMMAND_PRIORITY_LOW,
    ),
  ];

  return () => {
    unregisters.forEach((unregister) => unregister());
  };
}
