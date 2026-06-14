import { $toggleLink } from "@lexical/link";
import {
  INSERT_CHECK_LIST_COMMAND,
  INSERT_ORDERED_LIST_COMMAND,
  INSERT_UNORDERED_LIST_COMMAND,
} from "@lexical/list";
import { $setBlocksType } from "@lexical/selection";
import {
  $createHeadingNode,
  $createQuoteNode,
} from "@lexical/rich-text";
import {
  $createParagraphNode,
  $getSelection,
  $isRangeSelection,
  FORMAT_TEXT_COMMAND,
  type ElementNode,
  type LexicalEditor,
} from "lexical";

type ToolbarCommand =
  | "bold"
  | "bullets"
  | "code"
  | "h1"
  | "h2"
  | "h3"
  | "italic"
  | "link"
  | "numbers"
  | "paragraph"
  | "quote"
  | "todo"
  | "unlink";

function button(label: string, title: string, onClick: () => void): HTMLButtonElement {
  const element = document.createElement("button");
  element.type = "button";
  element.className = "LEXICAL_TOOLBAR_BUTTON";
  element.title = title;
  element.textContent = label;

  element.addEventListener("mousedown", (event) => event.preventDefault());
  element.addEventListener("click", onClick);

  return element;
}

function setBlockType(editor: LexicalEditor, createNode: () => ElementNode): void {
  editor.update(() => {
    const selection = $getSelection();
    if ($isRangeSelection(selection)) {
      $setBlocksType(selection, createNode);
    }
  });
}

function runToolbarCommand(editor: LexicalEditor, command: ToolbarCommand): void {
  switch (command) {
    case "paragraph":
      setBlockType(editor, () => $createParagraphNode());
      break;
    case "h1":
    case "h2":
    case "h3":
      setBlockType(editor, () => $createHeadingNode(command));
      break;
    case "quote":
      setBlockType(editor, () => $createQuoteNode());
      break;
    case "bold":
      editor.dispatchCommand(FORMAT_TEXT_COMMAND, "bold");
      break;
    case "italic":
      editor.dispatchCommand(FORMAT_TEXT_COMMAND, "italic");
      break;
    case "code":
      editor.dispatchCommand(FORMAT_TEXT_COMMAND, "code");
      break;
    case "bullets":
      editor.dispatchCommand(INSERT_UNORDERED_LIST_COMMAND, undefined);
      break;
    case "numbers":
      editor.dispatchCommand(INSERT_ORDERED_LIST_COMMAND, undefined);
      break;
    case "todo":
      editor.dispatchCommand(INSERT_CHECK_LIST_COMMAND, undefined);
      break;
    case "link": {
      const url = window.prompt("Link URL");
      if (url) editor.update(() => $toggleLink(url));
      break;
    }
    case "unlink":
      editor.update(() => $toggleLink(null));
      break;
  }
}

function toolbarTemplateFor(templateId: string): HTMLTemplateElement {
  const template = document.getElementById(templateId);

  if (!(template instanceof HTMLTemplateElement)) {
    throw new Error(`Missing Lexical toolbar template: ${templateId}`);
  }

  return template;
}

function toolbarCommandFor(element: Element): ToolbarCommand | undefined {
  const command = element.getAttribute("data-command");

  if (
    command === "bold" ||
    command === "bullets" ||
    command === "code" ||
    command === "h1" ||
    command === "h2" ||
    command === "h3" ||
    command === "italic" ||
    command === "link" ||
    command === "numbers" ||
    command === "paragraph" ||
    command === "quote" ||
    command === "todo" ||
    command === "unlink"
  ) {
    return command;
  }

  return undefined;
}

export function toolbarFor(editor: LexicalEditor, templateId: string): HTMLDivElement {
  const element = toolbarTemplateFor(templateId).content.firstElementChild?.cloneNode(true);

  if (!(element instanceof HTMLDivElement)) {
    throw new Error(`Invalid Lexical toolbar template: ${templateId}`);
  }

  const toolbar = element;

  toolbar.querySelectorAll("[data-command]").forEach((element) => {
    const command = toolbarCommandFor(element);
    if (!command) return;

    element.addEventListener("mousedown", (event) => event.preventDefault());
    element.addEventListener("click", () => runToolbarCommand(editor, command));
  });

  return toolbar;
}

export function floatingToolbarFor(editor: LexicalEditor): HTMLDivElement {
  const toolbar = document.createElement("div");
  toolbar.className = "LEXICAL_FLOATING_TOOLBAR";
  toolbar.hidden = true;

  toolbar.append(
    button("B", "Bold", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "bold")),
    button("I", "Italic", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "italic")),
    button("Code", "Inline code", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "code")),
    button("Link", "Add link", () => {
      const url = window.prompt("Link URL");
      if (url) editor.update(() => $toggleLink(url));
    }),
    button("Unlink", "Remove link", () => editor.update(() => $toggleLink(null))),
  );

  return toolbar;
}

function selectedRangeRect(root: HTMLElement): DOMRect | undefined {
  const selection = window.getSelection();
  if (!selection || selection.rangeCount === 0 || selection.isCollapsed) return undefined;

  const anchorNode = selection.anchorNode;
  const focusNode = selection.focusNode;
  if (!anchorNode || !focusNode || !root.contains(anchorNode) || !root.contains(focusNode)) {
    return undefined;
  }

  const range = selection.getRangeAt(0);
  const rect = range.getBoundingClientRect();
  if (rect.width === 0 && rect.height === 0) return undefined;

  return rect;
}

export function updateFloatingToolbar(
  editor: LexicalEditor,
  root: HTMLElement,
  toolbar: HTMLElement,
): void {
  editor.getEditorState().read(() => {
    const selection = $getSelection();
    if (!$isRangeSelection(selection) || selection.isCollapsed()) {
      toolbar.hidden = true;
      return;
    }

    const rect = selectedRangeRect(root);
    if (!rect) {
      toolbar.hidden = true;
      return;
    }

    toolbar.hidden = false;
    toolbar.style.left = `${rect.left + rect.width / 2}px`;
    toolbar.style.top = `${rect.top + window.scrollY}px`;
  });
}
