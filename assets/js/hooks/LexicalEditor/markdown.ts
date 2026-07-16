import {
  CHECK_LIST,
  CODE,
  TRANSFORMERS,
  UNORDERED_LIST,
  type Transformer,
} from "@lexical/markdown";
import { youtubeTransformer } from "./youtube";

const defaultMarkdownTransformers = TRANSFORMERS.filter(
  (transformer) => transformer !== CODE && transformer !== UNORDERED_LIST,
);

export const markdownTransformers: Transformer[] = [
  youtubeTransformer,
  CHECK_LIST,
  UNORDERED_LIST,
  ...defaultMarkdownTransformers,
];

export const preserveNewLines = true;

export function normalizeExportedMarkdown(markdown: string): string {
  return markdown.replace(/^(\s*[-*+]\s+\[[ xX]\]\s+)\[[ xX]\]\s+/gm, "$1");
}
