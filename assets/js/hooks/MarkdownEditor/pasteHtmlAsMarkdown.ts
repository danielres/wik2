import { EditorView } from "@codemirror/view";
import TurndownService from "turndown";

const turndown = new TurndownService({
  bulletListMarker: "-",
  codeBlockStyle: "fenced",
  emDelimiter: "_",
  headingStyle: "atx",
  strongDelimiter: "**",
});

turndown.addRule("removeEmptyLinks", {
  filter(node) {
    return node.nodeName == "A" && (node.textContent?.trim() ?? "") == "";
  },
  replacement() {
    return "";
  },
});

function htmlToMarkdown(html: string): string {
  return turndown.turndown(html).trim();
}

export function pasteHtmlAsMarkdown() {
  return EditorView.domEventHandlers({
    paste(event, view) {
      const html = event.clipboardData?.getData("text/html");
      if (!html) return false;

      const markdown = htmlToMarkdown(html);
      if (markdown == "") return false;

      event.preventDefault();
      view.dispatch(view.state.replaceSelection(markdown));

      return true;
    },
  });
}
