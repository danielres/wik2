import { expect, test } from "@playwright/test";

test.beforeEach(async ({ context, page }) => {
  await context.grantPermissions(["clipboard-read", "clipboard-write"]);
  await page.goto("/__test__/library-fields");
});

test("library rich text fields synchronize Markdown", async ({ page }) => {
  const editor = page.locator("#library-notes-editor .LEXICAL_EDITOR");

  await expect(editor).toContainText("Portable notes");
  await editor.press("End");
  await editor.pressSequentially(" updated");

  await expect(page.locator("#library-notes-textarea")).toHaveValue("Portable notes updated");
});

test("portable schemas copy to the clipboard", async ({ page }) => {
  await page.getByTestId("copy-schema").click();

  await expect(page.getByTestId("copy-schema")).toHaveAttribute("data-copy-state", "copied");
  await expect.poll(() => page.evaluate(() => navigator.clipboard.readText())).toBe(
    '{"format":"wik-library-schema","version":1}',
  );
});
