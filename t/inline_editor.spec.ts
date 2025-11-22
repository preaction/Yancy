import { test, expect, Locator, FrameLocator, Page } from "@playwright/test";

class EditorPage {
  contentTabLabel: Locator;
  contentTabPanel: Locator;
  contentFrame: Locator;
  contentDocument: FrameLocator;

  // Content Editor Toolbar
  textTagSelect: Locator;
  statusIcon: Locator;

  constructor(page: Page) {
    this.contentTabLabel = page.getByRole("button", { name: "Content" });
    this.contentTabPanel = page.getByRole("region", { name: "Content" });
    this.contentFrame = page.locator("#content-view");
    this.contentDocument = page.frameLocator("#content-view");
    this.statusIcon = page.locator(".status");
    this.textTagSelect = page.locator(".toolbar .text select[name=tag]");
  }
}

test.describe("inline content editor", () => {
  test.describe("editor initial page", () => {
    test.beforeEach(async ({ page }) => {
      await page.goto("/yancy");
    });

    test("initial page shows content panel", async ({ page }) => {
      const editor = new EditorPage(page);
      await expect(editor.contentTabLabel).toBeVisible();
      await expect(editor.contentTabPanel).toBeVisible();
    });
  });

  test.describe("content panel", () => {
    test.beforeEach(async ({ page }) => {
      await page.goto("/yancy");
      const editor = new EditorPage(page);
      await editor.contentTabLabel.click();
    });

    test("content panel shows app routes", async ({ page }) => {
      const editor = new EditorPage(page);
      const pageItems = editor.contentTabPanel.locator("li");
      const demoRouteNames = ["index", "multi-blocks", "artist-page"];
      expect(pageItems.count()).resolves.toBe(demoRouteNames.length);
      for (const name of demoRouteNames) {
        expect(pageItems.getByText(name)).toBeVisible();
      }
    });

    test("content panel can navigate to pages", async ({ page }) => {
      const editor = new EditorPage(page);
      await editor.contentTabPanel.getByText("multi-blocks").click();
      expect(editor.contentFrame.getAttribute("src")).resolves.toBe("/multi");
    });
  });

  test.describe("content frame", () => {
    test.beforeEach(async ({ page }) => {
      await page.goto("/yancy");
      const editor = new EditorPage(page);
      await editor.contentTabLabel.click();
      await editor.contentTabPanel.getByText("index").click();
    });

    test("shows default block content", async ({ page }) => {
      const editor = new EditorPage(page);
      await expect(editor.contentDocument.locator("body")).toContainText(
        "default landing page content",
      );
    });

    test("can edit a block's content", async ({ page, request }) => {
      const editor = new EditorPage(page);
      const block = editor.contentDocument.locator("y-block[name=landing]");
      expect(await block.getAttribute("contenteditable")).toBeTruthy();
      await block.fill("New landing page content");
      await expect(editor.statusIcon.getByTitle("Saved")).toBeVisible();

      const res = await request.get(
        "/yancy/api/blocks?name=landing&path=" + encodeURIComponent("/"),
      );
      expect(res.ok()).toBeTruthy();
      const apiBlocks = await res.json();
      expect(apiBlocks).toEqual(
        expect.objectContaining({
          items: expect.arrayContaining([
            expect.objectContaining({
              name: "landing",
              path: "/",
              content: "New landing page content",
            }),
          ]),
        }),
      );
      await request.delete(`/yancy/api/blocks/${apiBlocks.items[0].block_id}`);
    });

    test.describe("editor toolbar", () => {
      test.beforeEach(async ({ page }) => {
        await page.goto("/yancy");
        const editor = new EditorPage(page);
        await editor.contentTabLabel.click();
        await editor.contentTabPanel.getByText("index").click();
      });

      test("clicking in content document updates text toolbar", async ({
        page,
      }) => {
        const editor = new EditorPage(page);
        const landingBlock = editor.contentDocument.locator(
          "y-block[name=landing]",
        );
        await landingBlock.click();
        expect(editor.textTagSelect).toBeVisible();
        expect(editor.textTagSelect).toBeEnabled();
        await expect(editor.textTagSelect).toHaveValue("p");

        await landingBlock.locator("h1").click();
        expect(editor.textTagSelect).toBeEnabled();
        await expect(editor.textTagSelect).toHaveValue("h1");

        // XXX: Need slight delay to allow parent editor to be updated
        await editor.contentDocument.getByText("outside").click({ delay: 50 });
        expect(editor.textTagSelect).toBeDisabled();
      });

      test("modify block text style", async ({ page, request }) => {
        const editor = new EditorPage(page);
        const landingBlock = editor.contentDocument.locator(
          "y-block[name=landing]",
        );
        await landingBlock.locator("h1").click();
        await editor.textTagSelect.selectOption("h2");
        await expect(landingBlock.locator("h2")).toBeVisible();

        await expect(editor.statusIcon.getByTitle("Saved")).toBeVisible();
        const res = await request.get(
          "/yancy/api/blocks?name=landing&path=" + encodeURIComponent("/"),
        );
        expect(res.ok()).toBeTruthy();
        const apiBlocks = await res.json();
        expect(apiBlocks).toEqual(
          expect.objectContaining({
            items: expect.arrayContaining([
              expect.objectContaining({
                name: "landing",
                path: "/",
                content: expect.stringMatching("<h2>This is an H1</h2>"),
              }),
            ]),
          }),
        );
        await request.delete(
          `/yancy/api/blocks/${apiBlocks.items[0].block_id}`,
        );
      });
    });
  });

  test.describe("editor data api", () => {
    test("can fetch pages", async ({ request }) => {
      const pages = await request.get("/yancy/api/pages");
      expect(pages.ok()).toBeTruthy();
      expect(await pages.json()).toEqual(
        expect.objectContaining({
          items: expect.arrayContaining([
            expect.objectContaining({
              pattern: "/",
              name: "index",
              in_app: 1,
            }),
            expect.objectContaining({
              pattern: "/multi",
              name: "multi-blocks",
              in_app: 1,
            }),
            expect.objectContaining({
              pattern: "/artist/:slug",
              name: "artist-page",
              in_app: 1,
            }),
          ]),
          offset: 0,
          total: 3,
        }),
      );
    });
  });
});
