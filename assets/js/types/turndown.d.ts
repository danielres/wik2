declare module "turndown" {
  type TurndownRule = {
    filter: (node: Node) => boolean;
    replacement: (content: string, node: Node) => string;
  };

  export default class TurndownService {
    constructor(options?: Record<string, unknown>);
    addRule(key: string, rule: TurndownRule): this;
    turndown(input: string | Node): string;
  }
}
