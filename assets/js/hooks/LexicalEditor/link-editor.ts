import { $isLinkNode, $toggleLink, formatUrl, type LinkNode } from "@lexical/link";
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
  getDOMSelection,
  getDOMSelectionRange,
  KEY_ESCAPE_COMMAND,
  mergeRegister,
  registerEventListener,
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
  isOpen: () => boolean;
  openForSelection: () => void;
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

function selectionRect(root: HTMLElement): DOMRect | undefined {
  const domSelection = getDOMSelection(root.ownerDocument.defaultView);
  if (!domSelection || domSelection.isCollapsed) return undefined;

  const range = getDOMSelectionRange(domSelection, root);
  if (!range) return undefined;

  const rect = range.getBoundingClientRect();
  return rect.width === 0 && rect.height === 0 ? undefined : rect;
}

function unwrapLink(link: LinkNode): void {
  link.getChildren().forEach((child) => link.insertBefore(child));
  link.remove();
}

function safeRelativeUrl(url: string): string | undefined {
  if (/[\x00-\x1F\x7F\\]/.test(url)) return undefined;
  if (url.startsWith("//")) return undefined;
  if (url.startsWith("/") || url.startsWith("#") || url.startsWith("./") || url.startsWith("../")) {
    return url;
  }

  return undefined;
}

function safeLinkUrl(url: string): string | undefined {
  const trimmed = url.trim();
  if (!trimmed) return undefined;

  const relativeUrl = safeRelativeUrl(trimmed);
  if (relativeUrl) return relativeUrl;

  const formatted = formatUrl(trimmed);
  if (/[\x00-\x1F\x7F\\]/.test(formatted)) return undefined;

  try {
    const protocol = new URL(formatted).protocol;
    return protocol === "http:" ||
      protocol === "https:" ||
      protocol === "mailto:" ||
      protocol === "tel:"
      ? formatted
      : undefined;
  } catch {
    return undefined;
  }
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
    urlView.textContent = active.url;
    urlInput.value = active.url;

    const safeUrl = safeLinkUrl(active.url);
    if (safeUrl) {
      urlView.href = safeUrl;
    } else {
      urlView.removeAttribute("href");
    }

    positionFloating({
      anchorRect: active.rect,
      floating: element,
      offset: 8,
      preferredPlacement: "bottom",
    });
  };

  const showEditMode = () => {
    view.hidden = true;
    editMode.hidden = false;
    requestAnimationFrame(() => urlInput.focus());
  };

  const openForSelection = () => {
    editor.read("latest", () => {
      const selection = $getSelection();
      if (!$isRangeSelection(selection) || selection.isCollapsed()) return;

      const rect = selectionRect(root);
      if (!rect) return;

      const active = activeLinkFromNode(editor, linkFromSelection());
      if (active) {
        show(active, selection.clone());
      } else {
        activeKey = undefined;
        lastSelection = selection.clone();
        urlInput.value = "";
        positionFloating({
          anchorRect: rect,
          floating: element,
          offset: 8,
          preferredPlacement: "bottom",
        });
      }

      showEditMode();
    });
  };

  const updateFromSelection = () => {
    if (element.contains(document.activeElement) || (!element.hidden && !editMode.hidden)) return;

    const active = activeLinkFromNode(editor, linkFromSelection());

    if (active) {
      show(active, currentLinkSelection());
    } else {
      hide();
    }
  };

  const update = () => {
    editor.read("latest", updateFromSelection);
  };

  editButton.addEventListener("click", showEditMode);

  cancelButton.addEventListener("click", () => {
    if (!activeKey) {
      hide();
      root.focus();
      return;
    }

    view.hidden = false;
    editMode.hidden = true;
    root.focus();
  });

  element.addEventListener("submit", (event) => {
    event.preventDefault();

    const key = activeKey;
    const url = urlInput.value.trim();
    if (!key && !lastSelection) return;

    const safeUrl = safeLinkUrl(url);
    if (url !== "" && !safeUrl) {
      urlInput.setCustomValidity("Enter a safe http, https, mailto, tel, or relative URL.");
      urlInput.reportValidity();
      return;
    }

    const linkUrl = url === "" ? null : safeUrl!;
    urlInput.setCustomValidity("");

    editor.update(() => {
      if (lastSelection) {
        $setSelection(lastSelection.clone());
        $toggleLink(linkUrl);
      } else {
        if (!key) return;
        const node = $getNodeByKey(key);
        if (!$isLinkNode(node)) return;

        if (linkUrl === null) {
          unwrapLink(node);
        } else {
          node.setURL(linkUrl);
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

  const unregisterDocumentClick = () =>
    registerEventListener(document, "click", (event) => {
      const target = event.target;
      if (!(target instanceof Node)) return;
      if (root.contains(target) || element.contains(target)) return;

      hide();
    });

  return {
    element,
    hide,
    isOpen: () => !element.hidden,
    openForSelection,
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
