const slugify = (value, replacementPattern) =>
  value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(replacementPattern, "-");

export const SlugifyInput = {
  mounted() {
    const replacementPatternSource = this.el.dataset.slugifyPattern;

    if (!replacementPatternSource) {
      throw new Error("SlugifyInput requires data-slugify-pattern");
    }

    const replacementPattern = new RegExp(replacementPatternSource, "g");

    this.onInput = () => {
      const nextValue = slugify(this.el.value, replacementPattern);

      if (this.el.value !== nextValue) {
        const caretAtEnd =
          this.el.selectionStart === this.el.value.length &&
            this.el.selectionEnd === this.el.value.length;

        this.el.value = nextValue;

        if (caretAtEnd) {
          this.el.setSelectionRange(nextValue.length, nextValue.length);
        }
      }
    };

    this.el.addEventListener("input", this.onInput);
  },

  destroyed() {
    this.el.removeEventListener("input", this.onInput);
  },
};
