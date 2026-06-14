import { createEmptyHistoryState, registerHistory } from "@lexical/history";
import { $toggleLink, LinkNode } from "@lexical/link";
import {
  $createListItemNode,
  $createListNode,
  INSERT_CHECK_LIST_COMMAND,
  INSERT_ORDERED_LIST_COMMAND,
  INSERT_UNORDERED_LIST_COMMAND,
  ListItemNode,
  ListNode,
  registerCheckList,
  registerList,
} from "@lexical/list";
import {
  $convertFromMarkdownString,
  $convertToMarkdownString,
  CODE,
  registerMarkdownShortcuts,
  type Transformer,
  TRANSFORMERS,
} from "@lexical/markdown";
import { $setBlocksType } from "@lexical/selection";
import {
  $createHeadingNode,
  $createQuoteNode,
  HeadingNode,
  QuoteNode,
  registerRichText,
  type HeadingTagType,
} from "@lexical/rich-text";
import {
  $applyNodeReplacement,
  $createParagraphNode,
  $getNodeByKey,
  $getRoot,
  $getSelection,
  $isElementNode,
  $isRangeSelection,
  COMMAND_PRIORITY_LOW,
  DecoratorNode,
  FORMAT_TEXT_COMMAND,
  SELECTION_CHANGE_COMMAND,
  createEditor,
  type EditorConfig,
  type ElementNode,
  type LexicalNode,
  type LexicalEditor,
  type NodeKey,
  type SerializedLexicalNode,
  type Spread,
} from "lexical";

type LexicalHook = {
  activeBlockKey?: NodeKey;
  dragHandle?: HTMLButtonElement;
  dragKey?: NodeKey;
  dropIndicator?: HTMLDivElement;
  el: HTMLElement;
  editor?: LexicalEditor;
  floatingToolbar?: HTMLDivElement;
  insertButton?: HTMLButtonElement;
  insertMenu?: HTMLDivElement;
  pendingYoutubeInsertKey?: NodeKey;
  toolbar?: HTMLDivElement;
  unregister?: () => void;
  root?: HTMLDivElement;
  textarea?: HTMLTextAreaElement;
  youtubeDialog?: HTMLDialogElement;
};

type SerializedYouTubeNode = Spread<
  {
    videoId: string;
  },
  SerializedLexicalNode
>;

class YouTubeNode extends DecoratorNode<null> {
  __videoId: string;

  static getType(): string {
    return "youtube";
  }

  static clone(node: YouTubeNode): YouTubeNode {
    return new YouTubeNode(node.__videoId, node.__key);
  }

  static importJSON(serializedNode: SerializedLexicalNode): YouTubeNode {
    const videoId =
      "videoId" in serializedNode && typeof serializedNode.videoId === "string"
        ? serializedNode.videoId
        : "";

    return new YouTubeNode(videoId);
  }

  constructor(videoId: string, key?: NodeKey) {
    super(key);
    this.__videoId = videoId;
  }

  exportJSON(): SerializedYouTubeNode {
    return {
      ...super.exportJSON(),
      videoId: this.__videoId,
    };
  }

  createDOM(_config: EditorConfig): HTMLElement {
    const wrapper = document.createElement("div");
    wrapper.className = "LEXICAL_YOUTUBE_EMBED";

    const iframe = document.createElement("iframe");
    iframe.width = "560";
    iframe.height = "315";
    iframe.src = `https://www.youtube-nocookie.com/embed/${this.__videoId}`;
    iframe.frameBorder = "0";
    iframe.allow =
      "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";
    iframe.allowFullscreen = true;
    iframe.title = "YouTube video";

    wrapper.appendChild(iframe);

    return wrapper;
  }

  updateDOM(prevNode: YouTubeNode, dom: HTMLElement): boolean {
    if (prevNode.__videoId === this.__videoId) return false;

    const iframe = dom.querySelector("iframe");
    if (iframe instanceof HTMLIFrameElement) {
      iframe.src = `https://www.youtube-nocookie.com/embed/${this.__videoId}`;
    }

    return false;
  }

  decorate(): null {
    return null;
  }

  getTextContent(): string {
    return youtubeIframeMarkdown(this.__videoId);
  }

  isInline(): boolean {
    return false;
  }

  isIsolated(): boolean {
    return true;
  }

  getVideoId(): string {
    return this.__videoId;
  }
}

function $createYouTubeNode(videoId: string): YouTubeNode {
  return $applyNodeReplacement(new YouTubeNode(videoId));
}

function $isYouTubeNode(node: LexicalNode | null | undefined): node is YouTubeNode {
  return node instanceof YouTubeNode;
}

function youtubeIdFromIframeHtml(html: string): string | undefined {
  const src = html.match(/\bsrc="([^"]+)"/i)?.[1];
  if (!src) return undefined;

  return youtubeIdFromUrl(src);
}

const youtubeTransformer: Transformer = {
  dependencies: [YouTubeNode],
  export: (node) => {
    if (!$isYouTubeNode(node)) return null;

    return youtubeIframeMarkdown(node.getVideoId());
  },
  handleImportAfterStartMatch: ({ lines, rootNode, startLineIndex }) => {
    const iframeLines: string[] = [];

    for (let index = startLineIndex; index < lines.length; index += 1) {
      iframeLines.push(lines[index]);

      if (/<\/iframe>\s*$/i.test(lines[index])) {
        const videoId = youtubeIdFromIframeHtml(iframeLines.join("\n"));
        if (!videoId) return null;

        rootNode.append($createYouTubeNode(videoId));
        return [true, index];
      }
    }

    return null;
  },
  regExpEnd: /^<\/iframe>\s*$/i,
  regExpStart: /^<iframe\b/i,
  replace: (rootNode, _children, startMatch, _endMatch, linesInBetween) => {
    const html = [startMatch[0], ...(linesInBetween || []), "</iframe>"].join("\n");
    const videoId = youtubeIdFromIframeHtml(html);
    if (!videoId) return false;

    rootNode.append($createYouTubeNode(videoId));
  },
  type: "multiline-element",
};

const markdownTransformers: Transformer[] = [
  youtubeTransformer,
  ...TRANSFORMERS.filter((transformer) => transformer !== CODE),
];
const preserveNewLines = true;

function textareaFor(editor: HTMLElement): HTMLTextAreaElement | undefined {
  const textareaId = editor.dataset.textareaId;
  if (!textareaId) return undefined;

  const element = document.getElementById(textareaId);
  if (element instanceof HTMLTextAreaElement) return element;

  return undefined;
}

function dispatchTextareaInput(textarea: HTMLTextAreaElement, value: string): void {
  textarea.value = value;
  textarea.dispatchEvent(new Event("input", { bubbles: true }));
}

function normalizeExportedMarkdown(markdown: string): string {
  return markdown.replace(/^(\s*[-*+]\s+\[[ xX]\]\s+)\[[ xX]\]\s+/gm, "$1");
}

function youtubeIdFromUrl(input: string): string | undefined {
  const trimmed = input.trim();
  if (/^[A-Za-z0-9_-]{11}$/.test(trimmed)) return trimmed;

  try {
    const url = new URL(trimmed);
    const host = url.hostname.replace(/^www\./, "");

    if (host === "youtu.be") {
      const id = url.pathname.split("/").filter(Boolean)[0];
      return id && /^[A-Za-z0-9_-]{11}$/.test(id) ? id : undefined;
    }

    if (
      host === "youtube.com" ||
      host === "m.youtube.com" ||
      host === "youtube-nocookie.com"
    ) {
      const watchId = url.searchParams.get("v");
      if (watchId && /^[A-Za-z0-9_-]{11}$/.test(watchId)) return watchId;

      const parts = url.pathname.split("/").filter(Boolean);
      const id = parts[0] === "embed" || parts[0] === "shorts" ? parts[1] : undefined;
      return id && /^[A-Za-z0-9_-]{11}$/.test(id) ? id : undefined;
    }
  } catch {
    return undefined;
  }

  return undefined;
}

function youtubeIframeMarkdown(id: string): string {
  return `<iframe
    width="560"
    height="315"
    src="https://www.youtube-nocookie.com/embed/${id}"
    frameborder="0"
    allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
    allowfullscreen=""
    title="YouTube video"
>
</iframe>`;
}

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

function setBlockType(editor: LexicalEditor, createNode: () => ElementNode) {
  editor.update(() => {
    const selection = $getSelection();
    if ($isRangeSelection(selection)) {
      $setBlocksType(selection, createNode);
    }
  });
}

function headingButton(editor: LexicalEditor, tag: HeadingTagType): HTMLButtonElement {
  return button(tag.toUpperCase(), `Heading ${tag.slice(1)}`, () => {
    setBlockType(editor, () => $createHeadingNode(tag));
  });
}

function toolbarFor(editor: LexicalEditor): HTMLDivElement {
  const toolbar = document.createElement("div");
  toolbar.className = "LEXICAL_TOOLBAR";

  toolbar.append(
    button("P", "Paragraph", () => setBlockType(editor, () => $createParagraphNode())),
    headingButton(editor, "h1"),
    headingButton(editor, "h2"),
    headingButton(editor, "h3"),
    button("Quote", "Quote", () => setBlockType(editor, () => $createQuoteNode())),
    button("B", "Bold", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "bold")),
    button("I", "Italic", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "italic")),
    button("Code", "Inline code", () => editor.dispatchCommand(FORMAT_TEXT_COMMAND, "code")),
    button("Bullets", "Bullet list", () =>
      editor.dispatchCommand(INSERT_UNORDERED_LIST_COMMAND, undefined),
    ),
    button("Numbers", "Numbered list", () =>
      editor.dispatchCommand(INSERT_ORDERED_LIST_COMMAND, undefined),
    ),
    button("Todo", "Task list", () => editor.dispatchCommand(INSERT_CHECK_LIST_COMMAND, undefined)),
    button("Link", "Add link", () => {
      const url = window.prompt("Link URL");
      if (url) editor.update(() => $toggleLink(url));
    }),
    button("Unlink", "Remove link", () => editor.update(() => $toggleLink(null))),
  );

  return toolbar;
}

function floatingToolbarFor(editor: LexicalEditor): HTMLDivElement {
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

function updateFloatingToolbar(editor: LexicalEditor, root: HTMLElement, toolbar: HTMLElement): void {
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

function positionInsertButton(editor: LexicalEditor, key: NodeKey, button: HTMLElement): void {
  const element = editor.getElementByKey(key);
  if (!element) {
    button.hidden = true;
    return;
  }

  const rect = element.getBoundingClientRect();
  button.hidden = false;
  button.style.left = `${Math.max(8, rect.left - 60)}px`;
  button.style.top = `${rect.top + rect.height / 2}px`;
}

function positionInsertMenu(button: HTMLElement, menu: HTMLElement): void {
  const rect = button.getBoundingClientRect();

  menu.style.left = `${rect.left}px`;
  menu.style.top = `${rect.bottom + 6}px`;
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

function insertButtonFor(): HTMLButtonElement {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "LEXICAL_INSERT_BUTTON";
  button.hidden = true;
  button.title = "Insert block";
  button.ariaLabel = "Insert block";
  button.textContent = "+";

  button.addEventListener("mousedown", (event) => event.preventDefault());

  return button;
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

function insertMenuItem(label: string, onClick: () => void): HTMLButtonElement {
  const item = document.createElement("button");
  item.type = "button";
  item.className = "LEXICAL_INSERT_MENU_BUTTON";
  item.textContent = label;

  item.addEventListener("mousedown", (event) => event.preventDefault());
  item.addEventListener("click", onClick);

  return item;
}

function youtubeDialogFor(
  onSubmit: (videoId: string) => void,
  onCancel: () => void,
): HTMLDialogElement {
  const dialog = document.createElement("dialog");
  dialog.className = "LEXICAL_YOUTUBE_DIALOG";

  const form = document.createElement("form");
  form.method = "dialog";
  form.className = "LEXICAL_YOUTUBE_FORM";

  const title = document.createElement("div");
  title.className = "LEXICAL_YOUTUBE_TITLE";
  title.textContent = "YouTube embed";

  const input = document.createElement("input");
  input.type = "text";
  input.required = true;
  input.placeholder = "https://www.youtube.com/watch?v=W-hwnJUT854";
  input.className = "LEXICAL_YOUTUBE_INPUT";

  const error = document.createElement("div");
  error.className = "LEXICAL_YOUTUBE_ERROR";
  error.hidden = true;

  const actions = document.createElement("div");
  actions.className = "LEXICAL_YOUTUBE_ACTIONS";

  const cancel = document.createElement("button");
  cancel.type = "button";
  cancel.className = "LEXICAL_YOUTUBE_BUTTON secondary";
  cancel.textContent = "Cancel";
  cancel.addEventListener("click", () => dialog.close());

  const submit = document.createElement("button");
  submit.type = "submit";
  submit.className = "LEXICAL_YOUTUBE_BUTTON primary";
  submit.textContent = "Insert";

  actions.append(cancel, submit);
  form.append(title, input, error, actions);
  dialog.append(form);

  form.addEventListener("submit", (event) => {
    event.preventDefault();

    const id = youtubeIdFromUrl(input.value);
    if (!id) {
      error.textContent = "Enter a valid YouTube URL.";
      error.hidden = false;
      return;
    }

    error.hidden = true;
    onSubmit(id);
    input.value = "";
    dialog.returnValue = "inserted";
    dialog.close();
  });

  dialog.addEventListener("close", () => {
    error.hidden = true;
    if (dialog.returnValue !== "inserted") onCancel();
    dialog.returnValue = "";
  });

  return dialog;
}

function openYoutubeDialog(dialog: HTMLDialogElement): void {
  if (!dialog.open) dialog.showModal();

  const input = dialog.querySelector("input");
  if (input instanceof HTMLInputElement) {
    requestAnimationFrame(() => input.focus());
  }
}

function insertMenuFor(
  editor: LexicalEditor,
  getKey: () => NodeKey | undefined,
  openYoutubeEmbed: () => void,
): HTMLDivElement {
  const menu = document.createElement("div");
  menu.className = "LEXICAL_INSERT_MENU";
  menu.hidden = true;

  const insert = (createNode: () => ElementNode) => {
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

  menu.append(
    insertMenuItem("Paragraph", () => insert(() => $createParagraphNode())),
    insertMenuItem("Heading 1", () => insert(() => $createHeadingNode("h1"))),
    insertMenuItem("Heading 2", () => insert(() => $createHeadingNode("h2"))),
    insertMenuItem("Heading 3", () => insert(() => $createHeadingNode("h3"))),
    insertMenuItem("Quote", () => insert(() => $createQuoteNode())),
    insertMenuItem("Bullet list", () => insertList("bullet")),
    insertMenuItem("Numbered list", () => insertList("number")),
    insertMenuItem("Task list", () => insertList("check")),
    insertMenuItem("YouTube embed", () => {
      menu.hidden = true;
      openYoutubeEmbed();
    }),
  );

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

export const Lexical = {
  mounted(this: LexicalHook) {
    this.textarea = textareaFor(this.el);
    this.root = document.createElement("div");
    this.root.className = "LEXICAL_EDITOR";
    this.root.contentEditable = "true";
    this.root.role = "textbox";
    this.root.ariaMultiLine = "true";
    this.el.appendChild(this.root);

    const editor = createEditor({
      namespace: "WikMarkdownEditor",
      nodes: [HeadingNode, QuoteNode, ListNode, ListItemNode, LinkNode, YouTubeNode],
      onError(error) {
        throw error;
      },
    });

    editor.setRootElement(this.root);
    this.editor = editor;
    this.toolbar = toolbarFor(editor);
    this.floatingToolbar = floatingToolbarFor(editor);
    this.dragHandle = dragHandleFor();
    this.insertButton = insertButtonFor();
    this.youtubeDialog = youtubeDialogFor(
      (videoId) => {
        const key = this.pendingYoutubeInsertKey;
        this.pendingYoutubeInsertKey = undefined;
        if (!key) return;

        insertNodeAfter(editor, key, () => $createYouTubeNode(videoId));
        hideBlockControls();
      },
      () => {
        this.pendingYoutubeInsertKey = undefined;
      },
    );
    this.insertMenu = insertMenuFor(editor, () => this.activeBlockKey, () => {
      this.pendingYoutubeInsertKey = this.activeBlockKey;
      if (this.youtubeDialog) openYoutubeDialog(this.youtubeDialog);
    });
    this.dropIndicator = dropIndicatorFor();
    this.el.prepend(this.toolbar);
    document.body.appendChild(this.floatingToolbar);
    document.body.append(
      this.insertButton,
      this.dragHandle,
      this.insertMenu,
      this.dropIndicator,
      this.youtubeDialog,
    );

    const updateFloating = () => {
      if (this.root && this.floatingToolbar) {
        updateFloatingToolbar(editor, this.root, this.floatingToolbar);
      }
    };

    const updateHandle = () => {
      if (this.activeBlockKey && this.dragHandle && this.insertButton) {
        positionInsertButton(editor, this.activeBlockKey, this.insertButton);
        positionDragHandle(editor, this.activeBlockKey, this.dragHandle);
        if (this.insertMenu && !this.insertMenu.hidden) {
          positionInsertMenu(this.insertButton, this.insertMenu);
        }
      }
    };

    const hideBlockControls = () => {
      if (this.dragHandle) this.dragHandle.hidden = true;
      if (this.insertButton) this.insertButton.hidden = true;
      if (this.insertMenu) this.insertMenu.hidden = true;
      this.activeBlockKey = undefined;
    };

    const blockControlsHovered = () =>
      this.dragHandle?.matches(":hover") ||
      this.insertButton?.matches(":hover") ||
      this.insertMenu?.matches(":hover");

    const insertMenuOpen = () => Boolean(this.insertMenu && !this.insertMenu.hidden);

    const handleRootPointerMove = (event: PointerEvent) => {
      if (!this.root || !this.dragHandle || this.dragKey) return;

      const key = topLevelBlockKeyFromMouseEvent(editor, this.root, event);
      if (!key) {
        hideBlockControls();
        return;
      }

      this.activeBlockKey = key;
      positionDragHandle(editor, key, this.dragHandle);
      if (this.insertButton) positionInsertButton(editor, key, this.insertButton);
    };

    const hideHandle = () => {
      if (this.dragKey || blockControlsHovered() || insertMenuOpen()) return;
      hideBlockControls();
    };

    const handleRootMouseLeave = () => {
      window.setTimeout(hideHandle, 80);
    };

    const toggleInsertMenu = () => {
      if (!this.activeBlockKey || !this.insertButton || !this.insertMenu) return;

      this.insertMenu.hidden = !this.insertMenu.hidden;
      if (!this.insertMenu.hidden) positionInsertMenu(this.insertButton, this.insertMenu);
    };

    const closeInsertMenuOnOutsidePointerDown = (event: PointerEvent) => {
      if (!insertMenuOpen()) return;

      const target = event.target instanceof Node ? event.target : undefined;
      if (
        target &&
        (this.insertButton?.contains(target) || this.insertMenu?.contains(target))
      ) {
        return;
      }

      hideBlockControls();
    };

    const handleDragStart = (event: DragEvent) => {
      if (!this.activeBlockKey || !this.dragHandle) {
        event.preventDefault();
        return;
      }

      this.dragKey = this.activeBlockKey;
      this.dragHandle.classList.add("dragging");
      if (event.dataTransfer) {
        event.dataTransfer.effectAllowed = "move";
        event.dataTransfer.setData("application/x-wik-lexical-block", this.activeBlockKey);
        event.dataTransfer.setData("text/plain", this.activeBlockKey);
        event.dataTransfer.setDragImage(this.dragHandle, 8, 8);
      }
    };

    const handleRootDragOver = (event: DragEvent) => {
      if (!this.dragKey || !this.root || !this.dropIndicator) return;

      const targetKey = topLevelBlockKeyAtPoint(
        editor,
        this.root,
        event.clientX,
        event.clientY,
      );

      if (!targetKey || targetKey === this.dragKey) {
        this.dropIndicator.hidden = true;
        return;
      }

      event.preventDefault();
      if (event.dataTransfer) event.dataTransfer.dropEffect = "move";
      const position = dropPositionFor(editor, targetKey, event.clientY);
      positionDropIndicator(editor, targetKey, position, this.dropIndicator);
    };

    const handleRootDragEnter = (event: DragEvent) => {
      if (!this.dragKey) return;
      event.preventDefault();
    };

    const handleRootDrop = (event: DragEvent) => {
      if (!this.dragKey || !this.root || !this.dropIndicator) return;

      const targetKey = topLevelBlockKeyAtPoint(
        editor,
        this.root,
        event.clientX,
        event.clientY,
      );

      if (!targetKey || targetKey === this.dragKey) return;

      event.preventDefault();
      const position = dropPositionFor(editor, targetKey, event.clientY);
      moveBlock(editor, this.dragKey, targetKey, position);
      this.dropIndicator.hidden = true;
    };

    const clearDragState = () => {
      this.dragKey = undefined;
      this.dragHandle?.classList.remove("dragging");
      if (this.dropIndicator) this.dropIndicator.hidden = true;
      updateHandle();
    };

    const unregisters = [
      registerRichText(editor),
      registerList(editor),
      registerCheckList(editor),
      registerHistory(editor, createEmptyHistoryState(), 300),
      registerMarkdownShortcuts(editor, markdownTransformers),
      editor.registerUpdateListener(({ editorState }) => {
        if (!this.textarea) return;

        editorState.read(() => {
          dispatchTextareaInput(
            this.textarea!,
            normalizeExportedMarkdown(
              $convertToMarkdownString(markdownTransformers, undefined, preserveNewLines),
            ),
          );
        });

        updateFloating();
        updateHandle();
      }),
      editor.registerCommand(
        SELECTION_CHANGE_COMMAND,
        () => {
          updateFloating();
          return false;
        },
        COMMAND_PRIORITY_LOW,
      ),
      () => window.removeEventListener("resize", updateFloating),
      () => window.removeEventListener("scroll", updateFloating, true),
      () => this.root?.removeEventListener("pointermove", handleRootPointerMove),
      () => this.root?.removeEventListener("mouseleave", handleRootMouseLeave),
      () => this.root?.removeEventListener("dragenter", handleRootDragEnter),
      () => this.root?.removeEventListener("dragover", handleRootDragOver),
      () => this.root?.removeEventListener("drop", handleRootDrop),
      () => this.dragHandle?.removeEventListener("dragstart", handleDragStart),
      () => this.dragHandle?.removeEventListener("dragend", clearDragState),
      () => this.dragHandle?.removeEventListener("mouseleave", hideHandle),
      () => this.insertButton?.removeEventListener("click", toggleInsertMenu),
      () => this.insertButton?.removeEventListener("mouseleave", hideHandle),
      () => this.insertMenu?.removeEventListener("mouseleave", hideHandle),
      () => document.removeEventListener("pointerdown", closeInsertMenuOnOutsidePointerDown),
    ];

    window.addEventListener("resize", updateFloating);
    window.addEventListener("scroll", updateFloating, true);
    this.root.addEventListener("pointermove", handleRootPointerMove);
    this.root.addEventListener("mouseleave", handleRootMouseLeave);
    this.root.addEventListener("dragenter", handleRootDragEnter);
    this.root.addEventListener("dragover", handleRootDragOver);
    this.root.addEventListener("drop", handleRootDrop);
    this.dragHandle.addEventListener("dragstart", handleDragStart);
    this.dragHandle.addEventListener("dragend", clearDragState);
    this.dragHandle.addEventListener("mouseleave", hideHandle);
    this.insertButton.addEventListener("click", toggleInsertMenu);
    this.insertButton.addEventListener("mouseleave", hideHandle);
    this.insertMenu.addEventListener("mouseleave", hideHandle);
    document.addEventListener("pointerdown", closeInsertMenuOnOutsidePointerDown);

    this.unregister = () => {
      unregisters
        .slice()
        .reverse()
        .forEach((unregister) => unregister());
    };

    editor.update(() => {
      $convertFromMarkdownString(
        this.textarea?.value || "",
        markdownTransformers,
        undefined,
        preserveNewLines,
      );
    });

    requestAnimationFrame(() => this.root?.focus());
  },

  destroyed(this: LexicalHook) {
    this.unregister?.();
    this.editor?.setRootElement(null);
    this.insertButton?.remove();
    this.insertMenu?.remove();
    this.youtubeDialog?.remove();
    this.dragHandle?.remove();
    this.dropIndicator?.remove();
    this.floatingToolbar?.remove();
    this.toolbar?.remove();
    this.root?.remove();
  },
};
