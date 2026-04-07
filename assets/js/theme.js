const storageKey = "phx:theme";
const mediaQuery = window.matchMedia("(prefers-color-scheme: dark)");
const themeNames = {
  /* ⚠️ themes values must be in sync with "themes" in app.css */
  light: "garden",
  dark: "dim",
};

const normalizeThemeMode = (themeMode) =>
  themeMode === "light" || themeMode === "dark" ? themeMode : "system";

const resolveThemeMode = (themeMode) =>
  themeMode === "system" ? (mediaQuery.matches ? "dark" : "light") : themeMode;

export const applyTheme = (themeMode) => {
  const root = document.documentElement;
  const preference = normalizeThemeMode(themeMode);
  const resolvedMode = resolveThemeMode(preference);

  if (preference === "system") {
    localStorage.removeItem(storageKey);
  } else {
    localStorage.setItem(storageKey, preference);
  }

  root.dataset.theme = themeNames[resolvedMode];
  root.dataset.themeMode = preference;
  root.dataset.colorMode = resolvedMode;
};

export const initTheme = () => {
  applyTheme(localStorage.getItem(storageKey) || "system");

  window.addEventListener("storage", (e) => {
    if (e.key === storageKey) {
      applyTheme(e.newValue || "system");
    }
  });

  document.addEventListener("click", (e) => {
    const trigger = e.target.closest("[data-theme-toggle]");

    if (trigger) {
      applyTheme(trigger.dataset.themeMode);
    }
  });

  mediaQuery.addEventListener("change", () => {
    if (document.documentElement.dataset.themeMode === "system") {
      applyTheme("system");
    }
  });
};
