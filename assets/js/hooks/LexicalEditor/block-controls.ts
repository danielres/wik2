import {
  $createListItemNode,
  $createListNode,
} from "@lexical/list";
import {
  $createHeadingNode,
  $createQuoteNode,
} from "@lexical/rich-text";
import {
  $createParagraphNode,
  $getNodeByKey,
  $getRoot,
  $isElementNode,
  type LexicalEditor,
  type LexicalNode,
  type NodeKey,
} from "lexical";
import { positionFloating } from "./floating";

type BlockControlsOptions = {
  editor: LexicalEditor;
  insertMenuTemplateId: string;
  onYoutubeEmbed: (key: NodeKey) => void;
  root: HTMLElement;
};

export type BlockControls = {
  dragHandle: HTMLButtonElement;
  dropIndicator: HTMLDivElement;
  hide: () => void;
  insertMenu: HTMLDivElement;
  unregister: () => void;
  update: () => void;
};

type InsertCommand =
  | "bullets"
  | "h1"
  | "h2"
  | "h3"
  | "numbers"
  | "paragraph"
  | "quote"
  | "todo"
  | "youtube";

function closestTopLevelElement(root: HTMLElement, target: Node): HTMLElement | undefined {
  if (target === root) return undefined;

  let element = target instanceof HTMLElement ? target : target.parentElement;

  while (element && element.parentElement !== root) {
    element = element.parentElement;
  }

  return element && root.contains(element) ? element : undefined;
}

function topLevelElements(root: HTMLElement): HTMLElement[] {
  return Array.from(root.children).filter(
    (child): child is HTMLElement => child instanceof HTMLElement,
  );
}

function topLevelElementNearY(root: HTMLElement, clientY: number): HTMLElement | undefined {
  const children = topLevelElements(root);

  if (children.length === 0) return undefined;

  const containingChild = children.find((child) => {
    const rect = child.getBoundingClientRect();
    return clientY >= rect.top && clientY <= rect.bottom;
  });

  if (containingChild) return containingChild;

  return children.reduce((nearest, child) => {
    const nearestRect = nearest.getBoundingClientRect();
    const childRect = child.getBoundingClientRect();
    const nearestDistance = Math.min(
      Math.abs(clientY - nearestRect.top),
      Math.abs(clientY - nearestRect.bottom),
    );
    const childDistance = Math.min(
      Math.abs(clientY - childRect.top),
      Math.abs(clientY - childRect.bottom),
    );

    return childDistance < nearestDistance ? child : nearest;
  });
}

function topLevelBlockKeyForElement(
  editor: LexicalEditor,
  root: HTMLElement,
  element: HTMLElement,
): NodeKey | undefined {
  const children = Array.from(root.children).filter(
    (child): child is HTMLElement => child instanceof HTMLElement,
  );
  const index = children.indexOf(element);
  if (index < 0) return undefined;

  let key: NodeKey | undefined;

  editor.getEditorState().read(() => {
    key = $getRoot().getChildAtIndex(index)?.getKey();
  });

  return key;
}

function topLevelBlockKeyFromMouseEvent(
  editor: LexicalEditor,
  root: HTMLElement,
  event: MouseEvent,
): NodeKey | undefined {
  const target = event.target instanceof Node ? event.target : undefined;
  const topLevelElement = target ? closestTopLevelElement(root, target) : undefined;
  const element = topLevelElement || topLevelElementNearY(root, event.clientY);

  return element ? topLevelBlockKeyForElement(editor, root, element) : undefined;
}

function topLevelBlockKeyAtPoint(
  editor: LexicalEditor,
  root: HTMLElement,
  clientX: number,
  clientY: number,
): NodeKey | undefined {
  const element = document.elementFromPoint(clientX, clientY);
  if (element && root.contains(element)) {
    const topLevelElement = closestTopLevelElement(root, element);
    return topLevelElement ? topLevelBlockKeyForElement(editor, root, topLevelElement) : undefined;
  }

  const topLevelElement = topLevelElementNearY(root, clientY);
  return topLevelElement ? topLevelBlockKeyForElement(editor, root, topLevelElement) : undefined;
}

function positionDragHandle(editor: LexicalEditor, key: NodeKey, handle: HTMLElement): void {
  const element = editor.getElementByKey(key);
  if (!element) {
    handle.hidden = true;
    return;
  }

  const rect = element.getBoundingClientRect();
  handle.hidden = false;
  handle.style.left = `${Math.max(8, rect.left - 30)}px`;
  handle.style.top = `${rect.top + rect.height / 2}px`;
}

function positionInsertMenu(anchor: HTMLElement, menu: HTMLElement): void {
  positionFloating({
    anchorRect: anchor.getBoundingClientRect(),
    floating: menu,
    offset: 6,
    preferredPlacement: "bottom",
  });
}

function dragHandleFor(): HTMLButtonElement {
  const handle = document.createElement("button");
  handle.type = "button";
  handle.className = "LEXICAL_BLOCK_HANDLE";
  handle.draggable = true;
  handle.hidden = true;
  handle.title = "Move block";
  handle.ariaLabel = "Move block";
  handle.textContent = "::";

  return handle;
}

function insertNodeAfter(editor: LexicalEditor, key: NodeKey, createNode: () => LexicalNode): void {
  editor.update(() => {
    const targetNode = $getNodeByKey(key);
    if (!targetNode) return;

    const newNode = createNode();
    targetNode.insertAfter(newNode);

    if ($isElementNode(newNode)) {
      newNode.selectStart();
    }
  });
}

function insertListBlockAfter(
  editor: LexicalEditor,
  key: NodeKey,
  listType: "bullet" | "number" | "check",
): void {
  insertNodeAfter(editor, key, () => {
    const list = $createListNode(listType);
    list.append($createListItemNode(listType === "check" ? false : undefined));

    return list;
  });
}

function templateFor(templateId: string): HTMLTemplateElement {
  const template = document.getElementById(templateId);

  if (!(template instanceof HTMLTemplateElement)) {
    throw new Error(`Missing Lexical insert menu template: ${templateId}`);
  }

  return template;
}

function insertCommandFor(element: Element): InsertCommand | undefined {
  const command = element.getAttribute("data-insert-command");

  if (
    command === "bullets" ||
    command === "h1" ||
    command === "h2" ||
    command === "h3" ||
    command === "numbers" ||
    command === "paragraph" ||
    command === "quote" ||
    command === "todo" ||
    command === "youtube"
  ) {
    return command;
  }

  return undefined;
}

function insertMenuFor(
  editor: LexicalEditor,
  getKey: () => NodeKey | undefined,
  templateId: string,
  openYoutubeEmbed: (key: NodeKey) => void,
): HTMLDivElement {
  const element = templateFor(templateId).content.firstElementChild?.cloneNode(true);

  if (!(element instanceof HTMLDivElement)) {
    throw new Error(`Invalid Lexical insert menu template: ${templateId}`);
  }

  const menu = element;

  const insert = (createNode: () => LexicalNode) => {
    const key = getKey();
    if (!key) return;

    insertNodeAfter(editor, key, createNode);
    menu.hidden = true;
  };

  const insertList = (listType: "bullet" | "number" | "check") => {
    const key = getKey();
    if (!key) return;

    insertListBlockAfter(editor, key, listType);
    menu.hidden = true;
  };

  menu.querySelectorAll("[data-insert-command]").forEach((element) => {
    const command = insertCommandFor(element);
    if (!command) return;

    element.addEventListener("mousedown", (event) => event.preventDefault());
    element.addEventListener("click", () => {
      switch (command) {
        case "paragraph":
          insert(() => $createParagraphNode());
          break;
        case "h1":
        case "h2":
        case "h3":
          insert(() => $createHeadingNode(command));
          break;
        case "quote":
          insert(() => $createQuoteNode());
          break;
        case "bullets":
          insertList("bullet");
          break;
        case "numbers":
          insertList("number");
          break;
        case "todo":
          insertList("check");
          break;
        case "youtube": {
          const key = getKey();
          if (!key) return;

          menu.hidden = true;
          openYoutubeEmbed(key);
          break;
        }
      }
    });
  });

  return menu;
}

function dropIndicatorFor(): HTMLDivElement {
  const indicator = document.createElement("div");
  indicator.className = "LEXICAL_DROP_INDICATOR";
  indicator.hidden = true;

  return indicator;
}

function dropPositionFor(editor: LexicalEditor, key: NodeKey, clientY: number): "before" | "after" {
  const element = editor.getElementByKey(key);
  if (!element) return "after";

  const rect = element.getBoundingClientRect();
  return clientY < rect.top + rect.height / 2 ? "before" : "after";
}

function positionDropIndicator(
  editor: LexicalEditor,
  key: NodeKey,
  position: "before" | "after",
  indicator: HTMLElement,
): void {
  const element = editor.getElementByKey(key);
  if (!element) {
    indicator.hidden = true;
    return;
  }

  const rect = element.getBoundingClientRect();
  indicator.hidden = false;
  indicator.style.left = `${rect.left}px`;
  indicator.style.top = `${position === "before" ? rect.top : rect.bottom}px`;
  indicator.style.width = `${rect.width}px`;
}

function moveBlock(
  editor: LexicalEditor,
  draggedKey: NodeKey,
  targetKey: NodeKey,
  position: "before" | "after",
): void {
  if (draggedKey === targetKey) return;

  editor.update(() => {
    const draggedNode = $getNodeByKey(draggedKey);
    const targetNode = $getNodeByKey(targetKey);

    if (!draggedNode || !targetNode || draggedNode.is(targetNode)) return;

    if (position === "before") {
      targetNode.insertBefore(draggedNode);
    } else {
      targetNode.insertAfter(draggedNode);
    }

    draggedNode.selectStart();
  });
}

export function createBlockControls({
  editor,
  insertMenuTemplateId,
  onYoutubeEmbed,
  root,
}: BlockControlsOptions): BlockControls {
  let activeBlockKey: NodeKey | undefined;
  let dragKey: NodeKey | undefined;
  let ignoreNextClick = false;

  const dragHandle = dragHandleFor();
  const insertMenu = insertMenuFor(editor, () => activeBlockKey, insertMenuTemplateId, onYoutubeEmbed);
  const dropIndicator = dropIndicatorFor();

  const update = () => {
    if (activeBlockKey) {
      positionDragHandle(editor, activeBlockKey, dragHandle);
      if (!insertMenu.hidden) {
        positionInsertMenu(dragHandle, insertMenu);
      }
    }
  };

  const hide = () => {
    dragHandle.hidden = true;
    insertMenu.hidden = true;
    activeBlockKey = undefined;
  };

  const controlsHovered = () =>
    dragHandle.matches(":hover") || insertMenu.matches(":hover");

  const insertMenuOpen = () => !insertMenu.hidden;

  const handleRootPointerMove = (event: PointerEvent) => {
    if (dragKey) return;

    const key = topLevelBlockKeyFromMouseEvent(editor, root, event);
    if (!key) {
      hide();
      return;
    }

    activeBlockKey = key;
    positionDragHandle(editor, key, dragHandle);
  };

  const hideIfIdle = () => {
    if (dragKey || controlsHovered() || insertMenuOpen()) return;
    hide();
  };

  const handleRootMouseLeave = () => {
    window.setTimeout(hideIfIdle, 80);
  };

  const toggleInsertMenu = () => {
    if (!activeBlockKey) return;

    insertMenu.hidden = !insertMenu.hidden;
    if (!insertMenu.hidden) positionInsertMenu(dragHandle, insertMenu);
  };

  const closeInsertMenuOnOutsidePointerDown = (event: PointerEvent) => {
    if (!insertMenuOpen()) return;

    const target = event.target instanceof Node ? event.target : undefined;
    if (target && (dragHandle.contains(target) || insertMenu.contains(target))) {
      return;
    }

    hide();
  };

  const handleDragStart = (event: DragEvent) => {
    if (!activeBlockKey) {
      event.preventDefault();
      return;
    }

    dragKey = activeBlockKey;
    dragHandle.classList.add("dragging");
    if (event.dataTransfer) {
      event.dataTransfer.effectAllowed = "move";
      event.dataTransfer.setData("application/x-wik-lexical-block", activeBlockKey);
      event.dataTransfer.setData("text/plain", activeBlockKey);
      event.dataTransfer.setDragImage(dragHandle, 8, 8);
    }
  };

  const handleRootDragOver = (event: DragEvent) => {
    if (!dragKey) return;

    const targetKey = topLevelBlockKeyAtPoint(editor, root, event.clientX, event.clientY);

    if (!targetKey || targetKey === dragKey) {
      dropIndicator.hidden = true;
      return;
    }

    event.preventDefault();
    if (event.dataTransfer) event.dataTransfer.dropEffect = "move";
    const position = dropPositionFor(editor, targetKey, event.clientY);
    positionDropIndicator(editor, targetKey, position, dropIndicator);
  };

  const handleRootDragEnter = (event: DragEvent) => {
    if (!dragKey) return;
    event.preventDefault();
  };

  const handleRootDrop = (event: DragEvent) => {
    if (!dragKey) return;

    const targetKey = topLevelBlockKeyAtPoint(editor, root, event.clientX, event.clientY);

    if (!targetKey || targetKey === dragKey) return;

    event.preventDefault();
    const position = dropPositionFor(editor, targetKey, event.clientY);
    moveBlock(editor, dragKey, targetKey, position);
    dropIndicator.hidden = true;
  };

  const clearDragState = () => {
    ignoreNextClick = true;
    window.setTimeout(() => {
      ignoreNextClick = false;
    }, 0);
    dragKey = undefined;
    dragHandle.classList.remove("dragging");
    dropIndicator.hidden = true;
    update();
  };

  const handleDragHandleClick = () => {
    if (ignoreNextClick) return;

    toggleInsertMenu();
  };

  root.addEventListener("pointermove", handleRootPointerMove);
  root.addEventListener("mouseleave", handleRootMouseLeave);
  root.addEventListener("dragenter", handleRootDragEnter);
  root.addEventListener("dragover", handleRootDragOver);
  root.addEventListener("drop", handleRootDrop);
  dragHandle.addEventListener("dragstart", handleDragStart);
  dragHandle.addEventListener("dragend", clearDragState);
  dragHandle.addEventListener("click", handleDragHandleClick);
  dragHandle.addEventListener("mouseleave", hideIfIdle);
  insertMenu.addEventListener("mouseleave", hideIfIdle);
  document.addEventListener("pointerdown", closeInsertMenuOnOutsidePointerDown);

  return {
    dragHandle,
    dropIndicator,
    hide,
    insertMenu,
    unregister: () => {
      root.removeEventListener("pointermove", handleRootPointerMove);
      root.removeEventListener("mouseleave", handleRootMouseLeave);
      root.removeEventListener("dragenter", handleRootDragEnter);
      root.removeEventListener("dragover", handleRootDragOver);
      root.removeEventListener("drop", handleRootDrop);
      dragHandle.removeEventListener("dragstart", handleDragStart);
      dragHandle.removeEventListener("dragend", clearDragState);
      dragHandle.removeEventListener("click", handleDragHandleClick);
      dragHandle.removeEventListener("mouseleave", hideIfIdle);
      insertMenu.removeEventListener("mouseleave", hideIfIdle);
      document.removeEventListener("pointerdown", closeInsertMenuOnOutsidePointerDown);
    },
    update,
  };
}
