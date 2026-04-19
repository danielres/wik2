declare module "turndown" {
  export default class TurndownService {
    constructor(options?: Record<string, unknown>);
    turndown(input: string | Node): string;
  }
}
