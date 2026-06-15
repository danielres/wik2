import {
  $getNodeByKey,
  $getSelection,
  $isRangeSelection,
  $isTextNode,
  COMMAND_PRIORITY_HIGH,
  KEY_ARROW_DOWN_COMMAND,
  KEY_ARROW_UP_COMMAND,
  KEY_ENTER_COMMAND,
  KEY_ESCAPE_COMMAND,
  KEY_TAB_COMMAND,
  type LexicalEditor,
  type NodeKey,
} from "lexical";
import { positionFloating } from "./floating";

type WikilinkCompletionKind = "member" | "page" | "tag";

type WikilinkCompletionItem = {
  apply: string;
  kind: WikilinkCompletionKind;
  label: string;
};

type WikilinkCompletionMatch = {
  items: WikilinkCompletionItem[];
  nodeKey: NodeKey;
  replaceFrom: number;
  replaceTo: number;
};

type WikilinkCompletionsOptions = {
  editor: LexicalEditor;
  root: HTMLElement;
  templateId: string;
  wikilinkPaths: readonly string[];
  wikilinkTagNames: readonly string[];
  wikilinkUsernames: readonly string[];
};

export type WikilinkCompletions = {
  menu: HTMLDivElement;
  unregister: () => void;
  update: () => void;
};

function templateFor(templateId: string): HTMLTemplateElement {
  const template = document.getElementById(templateId);

  if (!(template instanceof HTMLTemplateElement)) {
    throw new Error(`Missing Lexical wikilink completion template: ${templateId}`);
  }

  return template;
}

function completionItemsFor({
  wikilinkPaths,
  wikilinkTagNames,
  wikilinkUsernames,
}: Pick<
  WikilinkCompletionsOptions,
  "wikilinkPaths" | "wikilinkTagNames" | "wikilinkUsernames"
>): WikilinkCompletionItem[] {
  return [
    ...wikilinkUsernames.map((username) => ({
      apply: `@${username}]]`,
      kind: "member" as const,
      label: `@${username}`,
    })),
    ...wikilinkTagNames.map((tagName) => ({
      apply: `#${tagName}]]`,
      kind: "tag" as const,
      label: `#${tagName}`,
    })),
    ...wikilinkPaths.map((path) => ({
      apply: `${path}]]`,
      kind: "page" as const,
      label: path,
    })),
  ];
}

function itemsForQuery(
  query: string,
  items: readonly WikilinkCompletionItem[],
): WikilinkCompletionItem[] {
  const kind =
    query.startsWith("@") ? "member" : query.startsWith("#") ? "tag" : "page";
  const normalizedQuery = query.toLocaleLowerCase();

  return items
    .filter((item) => item.kind === kind)
    .filter((item) => item.label.toLocaleLowerCase().includes(normalizedQuery))
    .slice(0, 8);
}

function currentMatch(items: readonly WikilinkCompletionItem[]): WikilinkCompletionMatch | undefined {
  const selection = $getSelection();
  if (!$isRangeSelection(selection) || !selection.isCollapsed()) return undefined;

  const anchor = selection.anchor;
  if (anchor.type !== "text") return undefined;

  const node = anchor.getNode();
  if (!$isTextNode(node)) return undefined;

  const textBeforeCursor = node.getTextContent().slice(0, anchor.offset);
  const match = /\[\[([^\]\n]*)$/.exec(textBeforeCursor);
  if (!match) return undefined;

  const query = match[1] || "";
  const matchedItems = itemsForQuery(query, items);
  if (matchedItems.length === 0) return undefined;

  return {
    items: matchedItems,
    nodeKey: anchor.key,
    replaceFrom: anchor.offset - query.length,
    replaceTo: anchor.offset,
  };
}

function currentSelectionRect(root: HTMLElement): DOMRect {
  const selection = window.getSelection();
  const range = selection && selection.rangeCount > 0 ? selection.getRangeAt(0) : undefined;
  const rect = range?.getBoundingClientRect();

  if (rect && (rect.width > 0 || rect.height > 0)) return rect;

  const rangeRect = range?.getClientRects()[0];
  if (rangeRect) return rangeRect;

  return root.getBoundingClientRect();
}

function optionLabelFor(option: HTMLElement): HTMLElement {
  const label = option.querySelector("[data-wikilink-completion-label]");
  if (!(label instanceof HTMLElement)) {
    throw new Error("Invalid Lexical wikilink completion option template");
  }

  return label;
}

function optionKindFor(option: HTMLElement): HTMLElement | undefined {
  const kind = option.querySelector("[data-wikilink-completion-kind]");
  return kind instanceof HTMLElement ? kind : undefined;
}

function setActiveOption(menu: HTMLElement, activeIndex: number): void {
  menu.querySelectorAll("[data-wikilink-completion-option]").forEach((option, index) => {
    option.classList.toggle("active", index === activeIndex);
    option.setAttribute("aria-selected", index === activeIndex ? "true" : "false");
  });
}

function completionKindLabel(kind: WikilinkCompletionKind): string {
  switch (kind) {
    case "member":
      return "Member";
    case "tag":
      return "Tag";
    case "page":
      return "Page";
  }
}

export function parseWikilinkDataset(element: HTMLElement, name: string): string[] {
  const value = element.dataset[name];
  if (!value) return [];

  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed.filter((item): item is string => typeof item === "string") : [];
  } catch {
    return [];
  }
}

export function createWikilinkCompletions({
  editor,
  root,
  templateId,
  wikilinkPaths,
  wikilinkTagNames,
  wikilinkUsernames,
}: WikilinkCompletionsOptions): WikilinkCompletions {
  const element = templateFor(templateId).content.firstElementChild?.cloneNode(true);

  if (!(element instanceof HTMLDivElement)) {
    throw new Error(`Invalid Lexical wikilink completion template: ${templateId}`);
  }

  const menu = element;
  const optionTemplate = menu.querySelector("[data-wikilink-completion-option]");
  if (!(optionTemplate instanceof HTMLButtonElement)) {
    throw new Error(`Invalid Lexical wikilink completion option template: ${templateId}`);
  }
  optionTemplate.remove();

  const items = completionItemsFor({ wikilinkPaths, wikilinkTagNames, wikilinkUsernames });
  let activeIndex = 0;
  let activeMatch: WikilinkCompletionMatch | undefined;

  const close = () => {
    menu.hidden = true;
    activeIndex = 0;
    activeMatch = undefined;
  };

  const applyItem = (item: WikilinkCompletionItem) => {
    const match = activeMatch;
    if (!match) return;

    editor.update(() => {
      const node = $getNodeByKey(match.nodeKey);
      if (!$isTextNode(node)) return;

      node.spliceText(match.replaceFrom, match.replaceTo - match.replaceFrom, item.apply, true);
    });

    close();
    root.focus();
  };

  const render = (match: WikilinkCompletionMatch) => {
    menu.replaceChildren();

    match.items.forEach((item, index) => {
      const option = optionTemplate.cloneNode(true);
      if (!(option instanceof HTMLButtonElement)) return;

      optionLabelFor(option).textContent = item.label;
      const kind = optionKindFor(option);
      if (kind) kind.textContent = completionKindLabel(item.kind);

      option.addEventListener("mousedown", (event) => event.preventDefault());
      option.addEventListener("click", () => applyItem(item));
      menu.appendChild(option);

      if (index === activeIndex) option.classList.add("active");
    });

    setActiveOption(menu, activeIndex);
  };

  const update = () => {
    editor.getEditorState().read(() => {
      const match = currentMatch(items);
      if (!match) {
        close();
        return;
      }

      activeMatch = match;
      activeIndex = Math.min(activeIndex, match.items.length - 1);
      render(match);

      positionFloating({
        anchorRect: currentSelectionRect(root),
        floating: menu,
        offset: 6,
        preferredPlacement: "bottom",
      });
    });
  };

  const moveActive = (delta: number) => {
    if (!activeMatch) return false;

    activeIndex = (activeIndex + delta + activeMatch.items.length) % activeMatch.items.length;
    setActiveOption(menu, activeIndex);
    return true;
  };

  const chooseActive = () => {
    const item = activeMatch?.items[activeIndex];
    if (!item) return false;

    applyItem(item);
    return true;
  };

  const unregisters = [
    editor.registerCommand(
      KEY_ARROW_DOWN_COMMAND,
      (event) => {
        if (menu.hidden || !moveActive(1)) return false;
        event.preventDefault();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
    editor.registerCommand(
      KEY_ARROW_UP_COMMAND,
      (event) => {
        if (menu.hidden || !moveActive(-1)) return false;
        event.preventDefault();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
    editor.registerCommand(
      KEY_ENTER_COMMAND,
      (event) => {
        if (menu.hidden || !chooseActive()) return false;
        event?.preventDefault();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
    editor.registerCommand(
      KEY_TAB_COMMAND,
      (event) => {
        if (menu.hidden || !chooseActive()) return false;
        event.preventDefault();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
    editor.registerCommand(
      KEY_ESCAPE_COMMAND,
      (event) => {
        if (menu.hidden) return false;
        event.preventDefault();
        close();
        return true;
      },
      COMMAND_PRIORITY_HIGH,
    ),
  ];

  return {
    menu,
    unregister: () => {
      unregisters.forEach((unregister) => unregister());
    },
    update,
  };
}
