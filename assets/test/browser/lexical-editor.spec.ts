import { expect, test } from "@playwright/test";

const editorSelector = ".LEXICAL_EDITOR";
const floatingToolbarSelector = ".LEXICAL_FLOATING_TOOLBAR";

test.beforeEach(async ({ page }) => {
  await page.goto("/__test__/lexical-editor");
  await expect(page.locator(editorSelector)).toContainText("Start with selected text");
});

test("synchronizes markdown with the Phoenix form textarea", async ({ page }) => {
  const editor = page.locator(editorSelector);
  await editor.press("End");
  await editor.pressSequentially(" updated");

  await expect(page.locator("#edit-block-markdown-textarea-browser-test")).toHaveValue(
    "Start with selected text updated",
  );
});

test("shows the floating toolbar on the first text selection", async ({ page }) => {
  await page.locator(`${editorSelector} p`).selectText();

  await expect(page.locator(floatingToolbarSelector)).toBeVisible();
});

test("formats the current selection and synchronizes markdown", async ({ page }) => {
  await page.locator(`${editorSelector} p`).selectText();
  await page.locator(`${floatingToolbarSelector} [data-command="bold"]`).click();

  await expect(page.locator(`${editorSelector} strong`)).toHaveText("Start with selected text");
  await expect(page.locator("#edit-block-markdown-textarea-browser-test")).toHaveValue(
    "**Start with selected text**",
  );
});

test("adds a link through the owned link editor", async ({ page }) => {
  await page.locator(`${editorSelector} p`).selectText();
  await page.locator(`${floatingToolbarSelector} [data-command="link"]`).click();

  const linkEditor = page.locator(".LEXICAL_LINK_EDITOR");
  await expect(linkEditor).toBeVisible();
  await expect(page.locator(floatingToolbarSelector)).toBeHidden();

  await linkEditor.locator("[data-link-url-input]").fill("https://example.com");
  await linkEditor.getByRole("button", { name: "Save" }).click();

  await expect(page.locator(`${editorSelector} a`)).toHaveAttribute("href", "https://example.com");
  await expect(page.locator("#edit-block-markdown-textarea-browser-test")).toHaveValue(
    "[Start with selected text](https://example.com)",
  );
});

test("hides the floating toolbar after the selection collapses", async ({ page }) => {
  const paragraph = page.locator(`${editorSelector} p`);
  await paragraph.selectText();
  await expect(page.locator(floatingToolbarSelector)).toBeVisible();

  await paragraph.click();
  await expect(page.locator(floatingToolbarSelector)).toBeHidden();
});

test("cleans up client-owned UI across LiveView remounts", async ({ page }) => {
  const toggle = page.getByTestId("toggle-editor");

  await toggle.click();
  await expect(page.locator(editorSelector)).toHaveCount(0);
  await expect(page.locator(floatingToolbarSelector)).toHaveCount(0);

  await toggle.click();
  await expect(page.locator(editorSelector)).toHaveCount(1);
  await expect(page.locator(floatingToolbarSelector)).toHaveCount(1);
});
