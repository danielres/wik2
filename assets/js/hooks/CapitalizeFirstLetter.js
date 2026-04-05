export const CapitalizeFirstLetter = {
  mounted() {
    this.el.addEventListener("input", () => {
      const value = this.el.value;
      if (!value) return;

      const nextValue = value.charAt(0).toUpperCase() + value.slice(1);
      if (nextValue === value) return;

      const start = this.el.selectionStart;
      const end = this.el.selectionEnd;

      this.el.value = nextValue;
      this.el.setSelectionRange(start, end);
    });
  },
};
