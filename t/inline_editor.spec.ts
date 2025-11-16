import ServerStarter from "@mojolicious/server-starter";
import { test, expect, Locator, FrameLocator, Page } from "@playwright/test";

if (process.env.YANCY_EDITOR_URL) {
  test.use({ baseURL: process.env.YANCY_EDITOR_URL });
} else {
  const server = await ServerStarter.newServer();
  await server.launch("perl", ["myapp.pl", "daemon", "-l", "http://*?fd=3"]);
  test.use({ baseURL: server.url() });
  test.afterAll(async () => {
    await server.close();
  });
}

class EditorPage {
  contentTabLabel: Locator;
  contentTabPanel: Locator;
  contentFrame: FrameLocator;
  constructor(page: Page) {
    this.contentTabLabel = page.getByRole("button", { name: "Content" });
    this.contentTabPanel = page.getByRole("region", { name: "Content" });
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
      expect(pageItems.count()).resolves.toBe(3);
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
              pattern: "/artist",
              name: "artist-list",
              in_app: 1,
            }),
            expect.objectContaining({
              pattern: "/artist/:slug",
              name: "artist-page",
              in_app: 1,
            }),
          ]),
          total: 3,
        }),
      );
    });
  });
});
