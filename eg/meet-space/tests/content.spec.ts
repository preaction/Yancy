import { test, expect } from "@playwright/test";
import ContentEditor from "../../../xt/integration/pages/ContentEditor";
import DatabaseEditor from "../../../xt/integration/pages/DatabaseEditor";

// This is the base number of pages (routes) set up in myapp.pl
// TODO: We should probably instead test that individual known pages show up in
// the list.
const BASE_PAGE_COUNT = 8;

test.describe("content editor", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/yancy");
  });

  test.describe("page menu", () => {
    test("page menu lists all pages", async ({ page }) => {
      const editor = new ContentEditor(page);
      await expect(editor.websiteTabPanel.getByRole("link")).toHaveCount(
        BASE_PAGE_COUNT,
      );
    });
    test("can add new page for privacy policy", async ({ page, browser }) => {
      const newPage = {
        name: "privacy",
        method: "get",
        pattern: "/about/privacy",
        title: "Privacy Policy",
        template: "blank",
      };
      const editor = new DatabaseEditor(page);
      await editor.openTable("pages");
      await editor.addButton.click();
      const form = editor.itemEditForm;
      for (const [k, v] of Object.entries(newPage)) {
        await form.getByLabel(k).fill(v);
      }
      await form.getByRole("button", { name: "save" }).click();
      await expect(form).not.toBeVisible();

      const table = editor.tableFor("pages");
      await expect(table).toContainText(newPage.pattern);
      await expect(table).toContainText(newPage.title);
      await expect(table).toContainText(newPage.name);

      const contentEditor = new ContentEditor(page);
      await contentEditor.websiteTabLabel.click();
      await expect(contentEditor.websiteTabPanel).toContainText(newPage.name);
      await expect(contentEditor.websiteTabPanel).toContainText(
        newPage.pattern,
      );
      await contentEditor.websiteTabPanel
        .getByRole("link", { name: newPage.name })
        .click();
      // FIXME: Always have to click this twice...
      await contentEditor.websiteTabPanel
        .getByRole("link", { name: newPage.name })
        .click();

      const placeholder = "Write your content here.";
      const newContent = "Our privacy policy is none of your business.";
      const el = contentEditor.websiteDocument.getByText(placeholder);
      await el.click();
      await el.fill(newContent);
      await contentEditor.waitForSave();

      const newBrowserPage = await browser.newPage();
      await newBrowserPage.goto(newPage.pattern);
      await expect(newBrowserPage.getByRole("main")).toContainText(newContent);
      await newBrowserPage.close();
    });
  });

  test.describe("home page", () => {
    test.beforeEach(async ({ page }) => {
      const editor = new ContentEditor(page);
      await editor.websiteTabPanel.getByRole("link", { name: /home/ }).click();
      // FIXME: Always have to click this twice...
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
      const oldText: string = (await el.textContent()) ?? "";
      expect(oldText).toBeTruthy();
      await el.fill(oldText + " " + newText);
      await editor.waitForSave();

      const newPage = await browser.newPage();
      await newPage.goto("/");
      await expect(newPage.getByText(blurb)).toContainText(oldText);
      await expect(newPage.getByText(blurb)).toContainText(newText);
      await newPage.close();
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
      const el = editor.websiteDocument.locator("y-block[name=about] .tiptap");
      await el.evaluate((el: any) => {
        el.editor.commands.clearContent();
        el.editor.commands.focus("end");
      });

      // TODO: Add a whole bunch of new content, including several
      // advanced-type nodes and marks.
      // TODO: Add features to ContentEditor class to encapsulate actions
      // in the content editing.

      await el.pressSequentially("We are a space to meet.\n", { delay: 100 });
      const headingText = "Let us meet you!";
      await el.pressSequentially(headingText, { delay: 100 });
      await editor.websiteDocument
        .getByRole("button", { name: "Text style" })
        .click();
      await editor.websiteDocument
        .getByRole("menuitemradio", { name: "Heading 2" })
        .click();
      await expect(el.locator("h2")).toContainText(headingText);

      const boldText = "space to meet";
      await expect(el.locator(`p:has-text("${boldText}")`)).toBeVisible();
      try {
        await el
          .locator(`:text("${boldText}")`)
          .evaluate((element: HTMLElement, text) => {
            const selection = window.getSelection() || new Selection();
            const content = element.innerText;
            const range = document.createRange();
            range.setStart(element.childNodes[0], content.indexOf(text));
            range.setEnd(
              element.childNodes[0],
              content.indexOf(text) + text.length,
            );
            selection.removeAllRanges();
            selection.addRange(range);
          }, boldText);
      } catch (err) {
        console.error(err);
      }
      await editor.websiteDocument
        .getByRole("button", { name: "bold" })
        .click();
      await expect(el.locator("strong")).toContainText(boldText);
    });
  });
});
