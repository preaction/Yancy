import { test, expect } from "@playwright/test";
import ContentEditor from "../../../xt/integration/pages/ContentEditor";

test.describe("content editor", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/yancy");
  });

  test("page menu lists all pages", async ({ page }) => {
    const editor = new ContentEditor(page);
    await expect(editor.websiteTabPanel.getByRole("link")).toHaveCount(9);
  });

  test.describe("home page", () => {
    test.beforeEach(async ({ page }) => {
      const editor = new ContentEditor(page);
      await editor.websiteTabPanel.getByRole("link", { name: /home/ }).click();
    });

    test("can see home page in editor", async ({ page }) => {
      const editor = new ContentEditor(page);
      await expect(
        editor.websiteDocument.getByRole("heading", { name: "Meet Space" }),
      ).toBeVisible();
    });

    test("can add to editable about us blurb", async ({ page, browser }) => {
      const editor = new ContentEditor(page);
      const blurb = /editable about us blurb/;
      const newText = "And I added to it.";
      const el = editor.websiteDocument.getByText(blurb);
      await el.click();
      await el.fill((await el.textContent()) + " " + newText);
      await editor.waitForSave();

      const newPage = await browser.newPage();
      await newPage.goto("/");
      await expect(newPage.getByText(blurb)).toContainText(newText);
    });
  });

  test.describe("about meet space (long user content)", () => {
    test.beforeEach(async ({ page }) => {
      const editor = new ContentEditor(page);
      await editor.websiteTabPanel
        .getByRole("link", { name: /^about/ })
        .click();
      // FIXME: Always need to click on the website tab panel twice...
      await editor.websiteTabPanel
        .getByRole("link", { name: /^about/ })
        .click();
    });

    test("can add some content", async ({ page }) => {
      const editor = new ContentEditor(page);
      const el = editor.websiteDocument.getByText("Write your");
      await el.click();
      // TODO: Add a whole bunch of new content, including several
      // advanced-type nodes and marks.
    });
  });
});
