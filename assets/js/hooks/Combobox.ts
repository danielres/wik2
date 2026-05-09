type ComboboxOption = {
  label: string;
  search?: string;
  value: string;
};

type PopoverElement = HTMLElement & {
  hidePopover?: () => void;
  showPopover?: () => void;
};

type ComboboxHook = {
  activeIndex: number;
  debounceTimer?: number;
  debounceMs: number;
  el: HTMLElement;
  emptyDisplay: string;
  emptyMessage: string;
  filteredOptions: ComboboxOption[];
  freeText: boolean;
  hiddenInput?: HTMLInputElement;
  label?: HTMLElement;
  list?: HTMLElement;
  onDocumentClick?: (event: MouseEvent) => void;
  options: ComboboxOption[];
  optionsByValue: Map<string, ComboboxOption>;
  panel?: PopoverElement;
  requestSerial: number;
  searchEvent?: string;
  searchInput?: HTMLInputElement;
  searchMinLength: number;
  staticOptions: ComboboxOption[];
  suggestedValues: string[];
  trigger?: HTMLButtonElement;
  pushEvent: (
    event: string,
    payload: Record<string, unknown>,
    callback: (reply: { options?: ComboboxOption[] }) => void,
  ) => void;
};

function parseOptions(element: HTMLElement): ComboboxOption[] {
  return JSON.parse(element.dataset.options || "[]") as ComboboxOption[];
}

function parseSuggestedValues(element: HTMLElement): string[] {
  return JSON.parse(element.dataset.suggestedValues || "[]") as string[];
}

function parseBoolean(value: string | undefined): boolean {
  return value === "true";
}

function parseInteger(value: string | undefined, fallback: number): number {
  const parsed = Number(value);

  return Number.isInteger(parsed) ? parsed : fallback;
}

function rebuildOptionIndex(hook: ComboboxHook) {
  hook.optionsByValue = new Map(hook.options.map((option) => [option.value, option]));
}

function bindElements(hook: ComboboxHook) {
  hook.staticOptions = parseOptions(hook.el);
  hook.options = hook.staticOptions;
  rebuildOptionIndex(hook);
  hook.suggestedValues = parseSuggestedValues(hook.el);
  hook.emptyDisplay = hook.el.dataset.emptyDisplay || "";
  hook.emptyMessage = hook.el.dataset.emptyMessage || "No matches";
  hook.debounceMs = parseInteger(hook.el.dataset.debounceMs, 250);
  hook.freeText = parseBoolean(hook.el.dataset.freeText);
  hook.searchEvent = hook.el.dataset.searchEvent || undefined;
  hook.searchMinLength = parseInteger(hook.el.dataset.searchMinLength, 1);

  const hiddenInput = hook.el.querySelector('[data-role="value"]');
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
  optionsByValue: Map<string, ComboboxOption>,
  value: string | null | undefined,
): ComboboxOption | undefined {
  if (!value) return undefined;

  return optionsByValue.get(value);
}

function currentSelectionLabel(hook: ComboboxHook): string {
  const currentValue = hook.hiddenInput?.value;
  const option = optionForValue(hook.optionsByValue, currentValue);

  if (option) return option.label;
  if (currentValue) return currentValue;

  return hook.emptyDisplay;
}

function syncTriggerLabel(hook: ComboboxHook) {
  if (hook.label) hook.label.textContent = currentSelectionLabel(hook);
}

function normalize(value: string): string {
  return value.trim().toLowerCase();
}

function closePanel(hook: ComboboxHook) {
  hook.panel?.hidePopover?.();
  hook.trigger?.setAttribute("aria-expanded", "false");
  hook.activeIndex = -1;

  if (hook.searchInput) hook.searchInput.value = "";
}

function openPanel(hook: ComboboxHook) {
  hook.panel?.showPopover?.();
  hook.trigger?.setAttribute("aria-expanded", "true");
}

function clearList(hook: ComboboxHook) {
  if (!hook.list) return;

  hook.list.replaceChildren();
  hook.activeIndex = -1;
}

function filterStaticOptions(hook: ComboboxHook, query: string): ComboboxOption[] {
  const normalizedQuery = normalize(query);

  if (normalizedQuery === "") {
    return hook.suggestedValues
      .map((value) => optionForValue(hook.optionsByValue, value))
      .filter((option): option is ComboboxOption => option !== undefined)
      .slice(0, 8);
  }

  return hook.staticOptions
    .filter((option) => (option.search || normalize(option.label)).includes(normalizedQuery))
    .slice(0, 12);
}

function highlightActiveOption(hook: ComboboxHook) {
  if (!hook.list) return;

  Array.from(hook.list.querySelectorAll("[data-option-index]")).forEach((element) => {
    if (!(element instanceof HTMLButtonElement)) return;

    const isActive = Number(element.dataset.optionIndex) === hook.activeIndex;
    element.classList.toggle("bg-base-200", isActive);
    element.setAttribute("aria-selected", isActive ? "true" : "false");

    if (isActive) element.scrollIntoView({ block: "nearest" });
  });
}

function commitSelection(hook: ComboboxHook, option: ComboboxOption) {
  if (!hook.hiddenInput) return;

  hook.hiddenInput.value = option.value;
  hook.hiddenInput.dispatchEvent(new Event("input", { bubbles: true }));
  hook.hiddenInput.dispatchEvent(new Event("change", { bubbles: true }));
  syncTriggerLabel(hook);
  closePanel(hook);
  hook.trigger?.focus();
}

function renderEmptyState(hook: ComboboxHook) {
  if (!hook.list) return;

  hook.list.replaceChildren();

  const emptyState = document.createElement("li");
  emptyState.className = "px-3 py-2 text-sm opacity-60";
  emptyState.textContent = hook.emptyMessage;
  hook.list.appendChild(emptyState);
}

function renderList(hook: ComboboxHook) {
  if (!hook.list) return;

  hook.list.replaceChildren();

  hook.filteredOptions.forEach((option, index) => {
    const item = document.createElement("li");
    const button = document.createElement("button");
    button.type = "button";
    button.className =
      "flex w-full items-center rounded-md px-3 py-2 text-left text-sm hover:bg-base-200 truncate";
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
}

function setRemoteOptions(hook: ComboboxHook, options: ComboboxOption[]) {
  hook.options = options;
  rebuildOptionIndex(hook);
  hook.filteredOptions = options;
}

function refreshStaticOptions(hook: ComboboxHook) {
  hook.options = hook.staticOptions;
  rebuildOptionIndex(hook);
  hook.filteredOptions = filterStaticOptions(hook, hook.searchInput?.value || "");

  if (hook.filteredOptions.length === 0) {
    renderEmptyState(hook);
  } else {
    renderList(hook);
  }

  openPanel(hook);
}

function refreshRemoteOptions(hook: ComboboxHook) {
  const query = hook.searchInput?.value || "";

  if (hook.debounceTimer) window.clearTimeout(hook.debounceTimer);

  if (normalize(query).length < hook.searchMinLength) {
    setRemoteOptions(hook, []);
    clearList(hook);
    openPanel(hook);
    return;
  }

  const requestSerial = ++hook.requestSerial;

  hook.debounceTimer = window.setTimeout(() => {
    hook.pushEvent(hook.searchEvent!, { q: query }, (reply: { options?: ComboboxOption[] }) => {
      if (requestSerial !== hook.requestSerial) return;

      setRemoteOptions(hook, reply.options || []);

      if (hook.filteredOptions.length === 0) {
        renderEmptyState(hook);
      } else {
        renderList(hook);
      }

      openPanel(hook);
    });
  }, hook.debounceMs);
}

function openSearch(hook: ComboboxHook) {
  hook.activeIndex = -1;

  if (hook.searchInput) {
    hook.searchInput.value = hook.freeText ? hook.hiddenInput?.value || "" : "";
  }

  if (hook.searchEvent) {
    clearList(hook);
    openPanel(hook);
  } else {
    refreshStaticOptions(hook);
  }

  requestAnimationFrame(() => {
    hook.searchInput?.focus();
    hook.searchInput?.select();
  });
}

export const Combobox = {
  mounted(this: ComboboxHook) {
    this.activeIndex = -1;
    this.debounceMs = 250;
    this.filteredOptions = [];
    this.options = [];
    this.optionsByValue = new Map();
    this.requestSerial = 0;
    bindElements(this);
    syncTriggerLabel(this);

    this.trigger?.addEventListener("click", () => {
      openSearch(this);
    });

    this.searchInput?.addEventListener("input", () => {
      if (this.freeText && this.hiddenInput && this.searchInput) {
        this.hiddenInput.value = this.searchInput.value;
        syncTriggerLabel(this);
      }

      this.activeIndex = -1;

      if (this.searchEvent) {
        refreshRemoteOptions(this);
      } else {
        refreshStaticOptions(this);
      }
    });

    this.searchInput?.addEventListener("keydown", (event) => {
      if (event.key === "ArrowDown") {
        event.preventDefault();

        if (this.filteredOptions.length === 0) return;

        this.activeIndex = Math.min(this.activeIndex + 1, this.filteredOptions.length - 1);
        highlightActiveOption(this);
        return;
      }

      if (event.key === "ArrowUp") {
        event.preventDefault();

        if (this.filteredOptions.length === 0) return;

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
        syncTriggerLabel(this);
        this.trigger?.focus();
      }
    });

    this.onDocumentClick = (event: MouseEvent) => {
      if (!(event.target instanceof Node)) return;
      if (this.el.contains(event.target)) return;

      closePanel(this);
      syncTriggerLabel(this);
    };

    document.addEventListener("click", this.onDocumentClick);
  },

  updated(this: ComboboxHook) {
    bindElements(this);
    syncTriggerLabel(this);
  },

  destroyed(this: ComboboxHook) {
    if (this.debounceTimer) window.clearTimeout(this.debounceTimer);

    if (this.onDocumentClick) {
      document.removeEventListener("click", this.onDocumentClick);
    }
  },
};
