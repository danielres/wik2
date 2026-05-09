type TimezoneOption = {
  label: string;
  search: string;
  value: string;
};

type PopoverElement = HTMLElement & {
  hidePopover?: () => void;
  showPopover?: () => void;
};

type TimezoneComboboxHook = {
  activeIndex: number;
  el: HTMLElement;
  filteredOptions: TimezoneOption[];
  hiddenInput?: HTMLInputElement;
  label?: HTMLElement;
  list?: HTMLElement;
  onDocumentClick?: (event: MouseEvent) => void;
  options: TimezoneOption[];
  optionsByValue: Map<string, TimezoneOption>;
  panel?: PopoverElement;
  searchInput?: HTMLInputElement;
  suggestedValues: string[];
  trigger?: HTMLButtonElement;
};

function parseOptions(element: HTMLElement): TimezoneOption[] {
  return JSON.parse(element.dataset.options || "[]") as TimezoneOption[];
}

function parseSuggestedValues(element: HTMLElement): string[] {
  return JSON.parse(element.dataset.suggestedValues || "[]") as string[];
}

function bindElements(hook: TimezoneComboboxHook) {
  hook.options = parseOptions(hook.el);
  hook.optionsByValue = new Map(hook.options.map((option) => [option.value, option]));
  hook.suggestedValues = parseSuggestedValues(hook.el);

  const hiddenInput = hook.el.querySelector('input[type="hidden"]');
  hook.hiddenInput = hiddenInput instanceof HTMLInputElement ? hiddenInput : undefined;

  const trigger = hook.el.querySelector('[data-role="trigger"]');
  hook.trigger = trigger instanceof HTMLButtonElement ? trigger : undefined;

  const label = hook.el.querySelector('[data-role="trigger-label"]');
  hook.label = label instanceof HTMLElement ? label : undefined;

  const panel = hook.el.querySelector('[data-role="panel"]');
  hook.panel = panel instanceof HTMLElement ? (panel as PopoverElement) : undefined;

  const searchInput = hook.el.querySelector('[data-role="search"]');
  hook.searchInput = searchInput instanceof HTMLInputElement ? searchInput : undefined;

  const list = hook.el.querySelector('[data-role="list"]');
  hook.list = list instanceof HTMLElement ? list : undefined;
}

function optionForValue(
  optionsByValue: Map<string, TimezoneOption>,
  value: string | null | undefined,
): TimezoneOption | undefined {
  if (!value) return undefined;

  return optionsByValue.get(value);
}

function currentSelection(hook: TimezoneComboboxHook): TimezoneOption | undefined {
  return optionForValue(hook.optionsByValue, hook.hiddenInput?.value);
}

function currentSelectionLabel(hook: TimezoneComboboxHook): string {
  return currentSelection(hook)?.label || hook.hiddenInput?.value || "Choose timezone";
}

function syncTriggerLabel(hook: TimezoneComboboxHook) {
  if (hook.label) hook.label.textContent = currentSelectionLabel(hook);
}

function normalize(value: string): string {
  return value.trim().toLowerCase();
}

function closePanel(hook: TimezoneComboboxHook) {
  hook.panel?.hidePopover?.();
  hook.trigger?.setAttribute("aria-expanded", "false");
  hook.activeIndex = -1;

  if (hook.searchInput) hook.searchInput.value = "";
}

function openPanel(hook: TimezoneComboboxHook) {
  hook.panel?.showPopover?.();
  hook.trigger?.setAttribute("aria-expanded", "true");
}

function filterOptions(hook: TimezoneComboboxHook, query: string): TimezoneOption[] {
  const normalizedQuery = normalize(query);

  if (normalizedQuery === "") {
    return hook.suggestedValues
      .map((value) => optionForValue(hook.optionsByValue, value))
      .filter((option): option is TimezoneOption => option !== undefined)
      .slice(0, 8);
  }

  return hook.options.filter((option) => option.search.includes(normalizedQuery)).slice(0, 12);
}

function highlightActiveOption(hook: TimezoneComboboxHook) {
  if (!hook.list) return;

  Array.from(hook.list.querySelectorAll("[data-option-index]")).forEach((element) => {
    if (!(element instanceof HTMLButtonElement)) return;

    const isActive = Number(element.dataset.optionIndex) === hook.activeIndex;
    element.classList.toggle("bg-base-200", isActive);
    element.setAttribute("aria-selected", isActive ? "true" : "false");

    if (isActive) element.scrollIntoView({ block: "nearest" });
  });
}

function commitSelection(hook: TimezoneComboboxHook, option: TimezoneOption) {
  if (!hook.hiddenInput) return;

  hook.hiddenInput.value = option.value;
  hook.hiddenInput.dispatchEvent(new Event("input", { bubbles: true }));
  hook.hiddenInput.dispatchEvent(new Event("change", { bubbles: true }));
  syncTriggerLabel(hook);
  closePanel(hook);
  hook.trigger?.focus();
}

function renderList(hook: TimezoneComboboxHook) {
  if (!hook.list) return;

  hook.list.replaceChildren();

  if (hook.filteredOptions.length === 0) {
    const emptyState = document.createElement("li");
    emptyState.className = "px-3 py-2 text-sm opacity-60";
    emptyState.textContent = "No matching timezone";
    hook.list.appendChild(emptyState);
    openPanel(hook);
    return;
  }

  hook.filteredOptions.forEach((option, index) => {
    const item = document.createElement("li");
    const button = document.createElement("button");
    button.type = "button";
    button.className =
      "flex w-full items-center rounded-md px-3 py-2 text-left text-sm hover:bg-base-200";
    button.dataset.optionIndex = String(index);
    button.role = "option";
    button.setAttribute("aria-selected", "false");
    button.textContent = option.label;
    button.addEventListener("mousedown", (event) => event.preventDefault());
    button.addEventListener("click", () => commitSelection(hook, option));
    item.appendChild(button);
    hook.list?.appendChild(item);
  });

  if (hook.activeIndex >= hook.filteredOptions.length) hook.activeIndex = 0;
  if (hook.activeIndex < 0) hook.activeIndex = 0;

  highlightActiveOption(hook);
  openPanel(hook);
}

function refreshOptions(hook: TimezoneComboboxHook) {
  hook.filteredOptions = filterOptions(hook, hook.searchInput?.value || "");
  renderList(hook);
}

function openSearch(hook: TimezoneComboboxHook) {
  hook.activeIndex = -1;
  if (hook.searchInput) hook.searchInput.value = "";
  refreshOptions(hook);

  requestAnimationFrame(() => {
    hook.searchInput?.focus();
  });
}

export const TimezoneCombobox = {
  mounted(this: TimezoneComboboxHook) {
    this.activeIndex = -1;
    this.filteredOptions = [];
    bindElements(this);
    syncTriggerLabel(this);

    this.trigger?.addEventListener("click", () => {
      openSearch(this);
    });

    this.searchInput?.addEventListener("input", () => {
      this.activeIndex = -1;
      refreshOptions(this);
    });

    this.searchInput?.addEventListener("keydown", (event) => {
      if (event.key === "ArrowDown") {
        event.preventDefault();
        const currentIndex = this.activeIndex;
        refreshOptions(this);
        this.activeIndex = Math.min(currentIndex + 1, this.filteredOptions.length - 1);
        highlightActiveOption(this);
        return;
      }

      if (event.key === "ArrowUp") {
        event.preventDefault();
        refreshOptions(this);
        this.activeIndex = Math.max(this.activeIndex - 1, 0);
        highlightActiveOption(this);
        return;
      }

      if (event.key === "Enter" && this.activeIndex >= 0) {
        event.preventDefault();
        const option = this.filteredOptions[this.activeIndex];
        if (option) commitSelection(this, option);
        return;
      }

      if (event.key === "Escape") {
        event.preventDefault();
        closePanel(this);
        this.trigger?.focus();
      }
    });

    this.onDocumentClick = (event: MouseEvent) => {
      if (!(event.target instanceof Node)) return;
      if (this.el.contains(event.target)) return;

      closePanel(this);
    };

    document.addEventListener("click", this.onDocumentClick);
  },

  updated(this: TimezoneComboboxHook) {
    bindElements(this);
    syncTriggerLabel(this);
  },

  destroyed(this: TimezoneComboboxHook) {
    if (this.onDocumentClick) {
      document.removeEventListener("click", this.onDocumentClick);
    }
  },
};
