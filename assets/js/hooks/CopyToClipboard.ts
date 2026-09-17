type CopyToClipboardHook = {
  el: HTMLElement;
  handleClick?: () => Promise<void>;
};

export const CopyToClipboard = {
  mounted(this: CopyToClipboardHook) {
    this.handleClick = async () => {
      const sourceId = this.el.dataset.copySourceId;
      const source = sourceId ? document.getElementById(sourceId) : null;

      if (!(source instanceof HTMLTextAreaElement)) return;

      try {
        await navigator.clipboard.writeText(source.value);
        this.el.dispatchEvent(
          new CustomEvent("library:schema-copied", { bubbles: true }),
        );
        this.el.setAttribute("data-copy-state", "copied");
      } catch (_error) {
        source.focus();
        source.select();
        this.el.setAttribute("data-copy-state", "select-manually");
      }
    };

    this.el.addEventListener("click", this.handleClick);
  },

  destroyed(this: CopyToClipboardHook) {
    if (this.handleClick) this.el.removeEventListener("click", this.handleClick);
  },
};
