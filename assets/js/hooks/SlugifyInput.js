const slugify = (value) =>
  value
    .toLowerCase()
    .normalize("NFD")
    .replace(/[\u0300-\u036f]/g, "")
    .replace(/[^a-z0-9]+/g, "-");

export const SlugifyInput = {
  mounted() {
    this.onInput = () => {
      const nextValue = slugify(this.el.value);

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
