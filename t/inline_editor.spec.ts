import { test, expect, Locator, FrameLocator, Page } from "@playwright/test";

class EditorPage {
  contentTabLabel: Locator;
  contentTabPanel: Locator;
  contentFrame: Locator;
  contentDocument: FrameLocator;

  // Content Editor Toolbar
  textTagSelect: Locator;
  statusIcon: Locator;

  // Database editor
  databaseTabLabel: Locator;
  databaseTabPanel: Locator;

  constructor(page: Page) {
    this.contentTabLabel = page.getByRole("button", { name: "Content" });
    this.contentTabPanel = page.getByRole("region", { name: "Content" });
    this.contentFrame = page.locator("#content-view");
    this.contentDocument = page.frameLocator("#content-view");
    this.statusIcon = page.locator(".status");
    this.textTagSelect = page.locator(".toolbar .text select[name=tag]");
    this.databaseTabLabel = page.getByRole("button", { name: "Database" });
    this.databaseTabPanel = page.getByRole("region", { name: "Database" });
  }

  async openPage(url: string): Promise<void> {
    await this.contentFrame.evaluate(
      (e, url: string) => e.setAttribute("src", url),
      url,
    );
  }

  async waitForSave(): Promise<void> {
    await expect(this.statusIcon.getByTitle("Saved")).toBeVisible();
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
      expect(pageItems.count()).resolves.toBeGreaterThanOrEqual(
        demoRouteNames.length,
      );
      for (const name of demoRouteNames) {
        expect(pageItems.getByText(name)).toBeVisible();
      }
    });

    test("content panel can navigate to pages", async ({ page }) => {
      const editor = new EditorPage(page);
      await editor.contentTabPanel.getByText("multi-blocks").click();
      expect(editor.contentFrame).toHaveAttribute("src", "/multi");
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
      expect(block).toHaveAttribute("contenteditable");
      await block.fill("New landing page content");
      await editor.waitForSave();

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

    test("editable limited tags", async ({ page, request }) => {
      const editor = new EditorPage(page);
      const url = "/fixture/restrict-editable";
      await editor.openPage(url);

      const block = editor.contentDocument.locator("y-block[name=schedule]");
      expect(block).not.toHaveAttribute("contenteditable");
      const cell = block.locator("tbody tr:first-child td:first-of-type");
      expect(cell).toHaveAttribute("contenteditable");
      const cellContent = "99";
      await cell.fill(cellContent);

      await editor.waitForSave();
      const res = await request.get(
        "/yancy/api/blocks?name=schedule&path=" + encodeURIComponent(url),
      );
      expect(res.ok()).toBeTruthy();
      const apiBlocks = await res.json();
      expect(apiBlocks).toEqual(
        expect.objectContaining({
          items: expect.arrayContaining([
            expect.objectContaining({
              content: expect.stringContaining(`<td>${cellContent}</td>`),
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

        await editor.waitForSave();
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
        }),
      );
    });
  });
});

test.describe("database editor", () => {
  test.beforeEach(async ({ page }) => {
    await page.goto("/yancy");
  });

  test.describe("database list", () => {
    test("lists all databases", async ({ page }) => {
      const databaseSchema = {
        blocks: {
          title: "Blocks",
          properties: {
            block_id: { type: "number", readOnly: true },
          },
        },
        pages: {
          title: "Pages",
          properties: {
            page_id: { type: "number", readOnly: true },
          },
        },
      };
      await page.route("*/**/api", async (route) => {
        const json = databaseSchema;
        await route.fulfill({ json });
      });

      const editor = new EditorPage(page);
      await editor.databaseTabLabel.click();
      const databaseItems = editor.databaseTabPanel.locator("li");
      expect(databaseItems.count()).resolves.toEqual(
        Object.keys(databaseSchema).length,
      );
    });
  });
});
