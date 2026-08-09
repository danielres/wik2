import type { Transformer } from "@lexical/markdown";
import {
  $applyNodeReplacement,
  DecoratorNode,
  type EditorConfig,
  type LexicalNode,
  type NodeKey,
  type SerializedLexicalNode,
  type Spread,
  type TextNode,
} from "lexical";

type SerializedYouTubeNode = Spread<
  {
    videoId: string;
  },
  SerializedLexicalNode
>;

export class YouTubeNode extends DecoratorNode<null> {
  __videoId: string;

  $config() {
    return this.config("youtube", { extends: DecoratorNode });
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
    wrapper.contentEditable = "false";
    wrapper.dataset.lexicalYoutubeKey = this.getKey();

    const iframe = document.createElement("iframe");
    iframe.width = "560";
    iframe.height = "315";
    iframe.src = `https://www.youtube-nocookie.com/embed/${this.__videoId}`;
    iframe.frameBorder = "0";
    iframe.allow =
      "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture";
    iframe.allowFullscreen = true;
    iframe.tabIndex = -1;
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
    return youtubeImageMarkdown(this.__videoId);
  }

  isInline(): boolean {
    return false;
  }

  isIsolated(): boolean {
    return true;
  }

  isKeyboardSelectable(): boolean {
    return true;
  }

  getVideoId(): string {
    return this.__videoId;
  }
}

export function $createYouTubeNode(videoId: string): YouTubeNode {
  return $applyNodeReplacement(new YouTubeNode(videoId));
}

export function $isYouTubeNode(node: LexicalNode | null | undefined): node is YouTubeNode {
  return node instanceof YouTubeNode;
}

export function youtubeIdFromUrl(input: string): string | undefined {
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

export function youtubeImageMarkdown(id: string): string {
  return `![](https://www.youtube-nocookie.com/embed/${id})`;
}

function youtubeIdFromImageMarkdown(markdown: string): string | undefined {
  const match = /^!\[[^\]\n]*\]\(([^()\s]+)\)$/.exec(markdown);
  return match ? youtubeIdFromUrl(match[1]) : undefined;
}

export const youtubeTransformer: Transformer = {
  dependencies: [YouTubeNode],
  export: (node) => {
    if (!$isYouTubeNode(node)) return null;

    return youtubeImageMarkdown(node.getVideoId());
  },
  importRegExp: /!\[[^\]\n]*\]\([^()\s]+\)/,
  regExp: /!\[[^\]\n]*\]\([^()\s]+\)$/,
  replace: (textNode: TextNode, match) => {
    const videoId = youtubeIdFromImageMarkdown(match[0]);
    if (!videoId) return;

    textNode.replace($createYouTubeNode(videoId));
  },
  trigger: ")",
  type: "text-match",
};
