import { CODE, TRANSFORMERS, type Transformer } from "@lexical/markdown";
import { youtubeTransformer } from "./youtube";

export const markdownTransformers: Transformer[] = [
  youtubeTransformer,
  ...TRANSFORMERS.filter((transformer) => transformer !== CODE),
];

export const preserveNewLines = true;

export function normalizeExportedMarkdown(markdown: string): string {
  return markdown.replace(/^(\s*[-*+]\s+\[[ xX]\]\s+)\[[ xX]\]\s+/gm, "$1");
}
