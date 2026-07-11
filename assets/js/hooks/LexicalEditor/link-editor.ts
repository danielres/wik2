import { $isLinkNode, $toggleLink, type LinkNode } from "@lexical/link";
import {
  $getNodeByKey,
  $getNearestNodeFromDOMNode,
  $getSelection,
  $isElementNode,
  $isRangeSelection,
  $isTextNode,
  $setSelection,
  CLICK_COMMAND,
  COMMAND_PRIORITY_LOW,
  KEY_ESCAPE_COMMAND,
  mergeRegister,
  SELECTION_CHANGE_COMMAND,
  type LexicalEditor,
  type LexicalNode,
  type NodeKey,
  type RangeSelection,
} from "lexical";

import { positionFloating } from "./floating";

type ActiveLink = {
  key: NodeKey;
  rect: DOMRect;
  url: string;
};

type LinkEditorOptions = {
  editor: LexicalEditor;
  root: HTMLElement;
  templateId: string;
};

export type LinkEditor = {
  element: HTMLFormElement;
  hide: () => void;
  unregister: () => void;
  update: () => void;
};

function templateFor(templateId: string): HTMLTemplateElement {
  const template = document.getElementById(templateId);
  if (!(template instanceof HTMLTemplateElement)) {
    throw new Error(`Missing Lexical link editor template: ${templateId}`);
  }

  return template;
}

function nearestLinkNode(node: LexicalNode | null | undefined): LinkNode | undefined {
  let current: LexicalNode | null | undefined = node;

  while (current) {
    if ($isLinkNode(current)) return current;
    current = current.getParent();
  }

  return undefined;
}

function adjacentLinkNode(node: LexicalNode, offset: number): LinkNode | undefined {
  if ($isTextNode(node)) {
    if (offset === 0) return nearestLinkNode(node.getPreviousSibling());
    if (offset === node.getTextContentSize()) return nearestLinkNode(node.getNextSibling());
  }

  if ($isElementNode(node)) {
    if (offset > 0) return nearestLinkNode(node.getChildAtIndex(offset - 1));
    return nearestLinkNode(node.getChildAtIndex(offset));
  }

  return undefined;
}

function linkFromSelection(): LinkNode | undefined {
  const selection = $getSelection();
  if (!$isRangeSelection(selection)) return undefined;

  return (
    nearestLinkNode(selection.anchor.getNode()) ||
    nearestLinkNode(selection.focus.getNode()) ||
    (selection.isCollapsed()
      ? adjacentLinkNode(selection.anchor.getNode(), selection.anchor.offset)
      : undefined)
  );
}

function currentLinkSelection(): RangeSelection | null {
  const selection = $getSelection();
  if (!$isRangeSelection(selection)) return null;
  if (!linkFromSelection()) return null;

  return selection.clone();
}

function activeLinkFromNode(
  editor: LexicalEditor,
  link: LinkNode | undefined,
): ActiveLink | undefined {
  if (!link) return undefined;

  const element = editor.getElementByKey(link.getKey());
  if (!element) return undefined;

  const rect = element.getBoundingClientRect();
  if (rect.width === 0 && rect.height === 0) return undefined;

  return {
    key: link.getKey(),
    rect,
    url: link.getURL(),
  };
}

function activeLinkFromClick(editor: LexicalEditor, root: HTMLElement, target: EventTarget | null) {
  if (!(target instanceof Node) || !root.contains(target)) return undefined;

  return activeLinkFromNode(editor, nearestLinkNode($getNearestNodeFromDOMNode(target)));
}

function unwrapLink(link: LinkNode): void {
  link.getChildren().forEach((child) => link.insertBefore(child));
  link.remove();
}

export function createLinkEditor({
  editor,
  root,
  templateId,
}: LinkEditorOptions): LinkEditor {
  const element = templateFor(templateId).content.firstElementChild?.cloneNode(true);
  if (!(element instanceof HTMLFormElement)) {
    throw new Error(`Invalid Lexical link editor template: ${templateId}`);
  }

  const view = element.querySelector("[data-link-view]");
  const editMode = element.querySelector("[data-link-edit-mode]");
  const urlView = element.querySelector("[data-link-url-view]");
  const urlInput = element.querySelector("[data-link-url-input]");
  const editButton = element.querySelector("[data-link-edit]");
  const unlinkButton = element.querySelector("[data-link-unlink]");
  const cancelButton = element.querySelector("[data-link-cancel]");

  if (!(view instanceof HTMLElement)) throw new Error(`Missing link view: ${templateId}`);
  if (!(editMode instanceof HTMLElement)) throw new Error(`Missing link edit mode: ${templateId}`);
  if (!(urlView instanceof HTMLAnchorElement)) throw new Error(`Missing link URL view: ${templateId}`);
  if (!(urlInput instanceof HTMLInputElement)) throw new Error(`Missing link URL input: ${templateId}`);
  if (!(editButton instanceof HTMLButtonElement)) throw new Error(`Missing link edit button: ${templateId}`);
  if (!(unlinkButton instanceof HTMLButtonElement)) throw new Error(`Missing link unlink button: ${templateId}`);
  if (!(cancelButton instanceof HTMLButtonElement)) throw new Error(`Missing link cancel button: ${templateId}`);

  let activeKey: NodeKey | undefined;
  let lastSelection: RangeSelection | null = null;

  const hide = () => {
    activeKey = undefined;
    lastSelection = null;
    element.hidden = true;
    view.hidden = false;
    editMode.hidden = true;
  };

  const show = (active: ActiveLink, selection: RangeSelection | null) => {
    activeKey = active.key;
    lastSelection = selection;
    urlView.href = active.url;
    urlView.textContent = active.url;
    urlInput.value = active.url;
    positionFloating({
      anchorRect: active.rect,
      floating: element,
      offset: 8,
      preferredPlacement: "bottom",
    });
  };

  const updateFromSelection = () => {
    if (element.contains(document.activeElement)) return;

    const active = activeLinkFromNode(editor, linkFromSelection());

    if (active) {
      show(active, currentLinkSelection());
    } else {
      hide();
    }
  };

  const update = () => {
    editor.getEditorState().read(updateFromSelection);
  };

  editButton.addEventListener("click", () => {
    view.hidden = true;
    editMode.hidden = false;
    requestAnimationFrame(() => urlInput.focus());
  });

  cancelButton.addEventListener("click", () => {
    view.hidden = false;
    editMode.hidden = true;
    root.focus();
  });

  element.addEventListener("submit", (event) => {
    event.preventDefault();

    const key = activeKey;
    const url = urlInput.value.trim();
    if (!key) return;

    editor.update(() => {
      if (lastSelection) {
        $setSelection(lastSelection.clone());
        $toggleLink(url === "" ? null : url);
      } else {
        const node = $getNodeByKey(key);
        if (!$isLinkNode(node)) return;

        if (url === "") {
          unwrapLink(node);
        } else {
          node.setURL(url);
        }
      }
    });

    view.hidden = false;
    editMode.hidden = true;
    root.focus();
    requestAnimationFrame(update);
  });

  unlinkButton.addEventListener("click", () => {
    const key = activeKey;
    if (!key) return;

    editor.update(() => {
      if (lastSelection) {
        $setSelection(lastSelection.clone());
        $toggleLink(null);
      } else {
        const node = $getNodeByKey(key);
        if ($isLinkNode(node)) unwrapLink(node);
      }
    });

    root.focus();
    hide();
  });

  const unregisterDocumentClick = () => {
    const handleClick = (event: MouseEvent) => {
      const target = event.target;
      if (!(target instanceof Node)) return;
      if (root.contains(target) || element.contains(target)) return;

      hide();
    };

    document.addEventListener("click", handleClick);
    return () => document.removeEventListener("click", handleClick);
  };

  return {
    element,
    hide,
    unregister: mergeRegister(
      unregisterDocumentClick(),
      editor.registerUpdateListener(({ editorState }) => {
        editorState.read(updateFromSelection);
      }),
      editor.registerCommand(
        SELECTION_CHANGE_COMMAND,
        () => {
          update();
          return false;
        },
        COMMAND_PRIORITY_LOW,
      ),
      editor.registerCommand(
        CLICK_COMMAND,
        (event) => {
          const active = activeLinkFromClick(editor, root, event.target);

          if (!active) {
            hide();
            return false;
          }

          event.preventDefault();
          show(active, currentLinkSelection());
          return true;
        },
        COMMAND_PRIORITY_LOW,
      ),
      editor.registerCommand(
        KEY_ESCAPE_COMMAND,
        () => {
          if (element.hidden) return false;

          hide();
          return true;
        },
        COMMAND_PRIORITY_LOW,
      ),
    ),
    update,
  };
}
