import { $isLinkNode, $toggleLink } from "@lexical/link";
import {
  $isListNode,
  INSERT_CHECK_LIST_COMMAND,
  INSERT_ORDERED_LIST_COMMAND,
  INSERT_UNORDERED_LIST_COMMAND,
} from "@lexical/list";
import { $setBlocksType } from "@lexical/selection";
import {
  $createHeadingNode,
  $createQuoteNode,
  $isHeadingNode,
  $isQuoteNode,
} from "@lexical/rich-text";
import {
  $createParagraphNode,
  $getSelection,
  $isParagraphNode,
  $isRangeSelection,
  FORMAT_TEXT_COMMAND,
  getDOMSelection,
  getDOMSelectionRange,
  type ElementNode,
  type LexicalEditor,
  type LexicalNode,
} from "lexical";
import { positionFloating } from "./floating";

type ToolbarCommand =
  | "bold"
  | "bullet"
  | "check"
  | "code"
  | "h1"
  | "h2"
  | "h3"
  | "italic"
  | "link"
  | "number"
  | "paragraph"
  | "quote"
  | "unlink";

type ToolbarOptions = {
  onEditLink: () => void;
};

function setBlockType(editor: LexicalEditor, createNode: () => ElementNode): void {
  editor.update(() => {
    const selection = $getSelection();
    if ($isRangeSelection(selection)) {
      $setBlocksType(selection, createNode);
    }
  });
}

function runToolbarCommand(
  editor: LexicalEditor,
  command: ToolbarCommand,
  options: ToolbarOptions,
): void {
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
    case "bullet":
      editor.dispatchCommand(INSERT_UNORDERED_LIST_COMMAND, undefined);
      break;
    case "number":
      editor.dispatchCommand(INSERT_ORDERED_LIST_COMMAND, undefined);
      break;
    case "check":
      editor.dispatchCommand(INSERT_CHECK_LIST_COMMAND, undefined);
      break;
    case "link":
      options.onEditLink();
      break;
    case "unlink":
      editor.update(() => $toggleLink(null));
      break;
  }
}

function templateFor(templateId: string): HTMLTemplateElement {
  const template = document.getElementById(templateId);

  if (!(template instanceof HTMLTemplateElement)) {
    throw new Error(`Missing Lexical template: ${templateId}`);
  }

  return template;
}

function toolbarCommandFor(element: Element): ToolbarCommand | undefined {
  const command = element.getAttribute("data-command");

  if (
    command === "bold" ||
    command === "bullet" ||
    command === "check" ||
    command === "code" ||
    command === "h1" ||
    command === "h2" ||
    command === "h3" ||
    command === "italic" ||
    command === "link" ||
    command === "number" ||
    command === "paragraph" ||
    command === "quote" ||
    command === "unlink"
  ) {
    return command;
  }

  return undefined;
}

function bindToolbarCommands(
  toolbar: HTMLElement,
  editor: LexicalEditor,
  options: ToolbarOptions,
): void {
  toolbar.querySelectorAll("[data-command]").forEach((element) => {
    const command = toolbarCommandFor(element);
    if (!command) return;

    element.addEventListener("mousedown", (event) => event.preventDefault());
    element.addEventListener("click", (event) => {
      event.stopPropagation();
      runToolbarCommand(editor, command, options);
    });
  });
}

function blockCommandForNode(node: LexicalNode): ToolbarCommand | undefined {
  if ($isHeadingNode(node)) {
    const tag = node.getTag();
    return tag === "h1" || tag === "h2" || tag === "h3" ? tag : undefined;
  }
  if ($isQuoteNode(node)) return "quote";
  if ($isParagraphNode(node)) return "paragraph";
  if ($isListNode(node)) return node.getListType();

  return undefined;
}

function selectedBlockCommand(): ToolbarCommand | undefined {
  const selection = $getSelection();
  if (!$isRangeSelection(selection)) return undefined;

  const anchorNode = selection.anchor.getNode();
  return blockCommandForNode(anchorNode.getTopLevelElementOrThrow());
}

function selectionHasLink(): boolean {
  const selection = $getSelection();
  if (!$isRangeSelection(selection)) return false;

  return selection.getNodes().some((node) => $isLinkNode(node) || $isLinkNode(node.getParent()));
}

function setToolbarState(toolbar: HTMLElement): void {
  const selection = $getSelection();
  const rangeSelection = $isRangeSelection(selection) ? selection : undefined;
  const activeBlockCommand = selectedBlockCommand();
  const hasLink = selectionHasLink();

  toolbar.querySelectorAll("[data-command]").forEach((element) => {
    if (!(element instanceof HTMLButtonElement)) return;

    const command = toolbarCommandFor(element);
    const active =
      !!command &&
      (command === activeBlockCommand ||
        (command === "bold" && !!rangeSelection?.hasFormat("bold")) ||
        (command === "italic" && !!rangeSelection?.hasFormat("italic")) ||
        (command === "code" && !!rangeSelection?.hasFormat("code")) ||
        (command === "link" && hasLink));

    if (command === "link") {
      element.disabled = !rangeSelection || rangeSelection.isCollapsed();
    } else if (command === "unlink") {
      element.disabled = !hasLink;
    }

    element.classList.toggle("active", active);
    element.setAttribute("aria-pressed", active ? "true" : "false");
  });
}

export function toolbarFor(
  editor: LexicalEditor,
  templateId: string,
  options: ToolbarOptions,
): HTMLDivElement {
  const element = templateFor(templateId).content.firstElementChild?.cloneNode(true);

  if (!(element instanceof HTMLDivElement)) {
    throw new Error(`Invalid Lexical toolbar template: ${templateId}`);
  }

  const toolbar = element;
  bindToolbarCommands(toolbar, editor, options);

  return toolbar;
}

export function updateToolbarState(editor: LexicalEditor, toolbar: HTMLElement): void {
  editor.read("latest", () => setToolbarState(toolbar));
}

export function floatingToolbarFor(
  editor: LexicalEditor,
  templateId: string,
  options: ToolbarOptions,
): HTMLDivElement {
  const element = templateFor(templateId).content.firstElementChild?.cloneNode(true);

  if (!(element instanceof HTMLDivElement)) {
    throw new Error(`Invalid Lexical floating toolbar template: ${templateId}`);
  }

  const toolbar = element;
  bindToolbarCommands(toolbar, editor, options);
  return toolbar;
}

export function updateFloatingToolbar(
  editor: LexicalEditor,
  root: HTMLElement,
  toolbar: HTMLElement,
  hiddenByOwnedUi: boolean,
): void {
  editor.read("latest", () => {
    const selection = $getSelection();
    const nativeSelection = getDOMSelection(root.ownerDocument.defaultView);

    if (
      hiddenByOwnedUi ||
      editor.isComposing() ||
      !$isRangeSelection(selection) ||
      selection.isCollapsed() ||
      !nativeSelection ||
      nativeSelection.rangeCount === 0 ||
      nativeSelection.isCollapsed
    ) {
      toolbar.hidden = true;
      return;
    }

    const anchorNode = nativeSelection.anchorNode;
    const focusNode = nativeSelection.focusNode;
    if (!anchorNode || !focusNode || !root.contains(anchorNode) || !root.contains(focusNode)) {
      toolbar.hidden = true;
      return;
    }

    const nativeRange = getDOMSelectionRange(nativeSelection, root);
    if (!nativeRange) {
      toolbar.hidden = true;
      return;
    }

    const rect = nativeRange.getBoundingClientRect();
    if (rect.width === 0 && rect.height === 0) {
      toolbar.hidden = true;
      return;
    }

    positionFloating({
      anchorRect: rect,
      floating: toolbar,
      offset: 7,
      preferredPlacement: "top",
    });
  });
}
