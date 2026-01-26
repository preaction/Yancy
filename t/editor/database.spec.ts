import { test, expect } from "@playwright/test";
import EditorPage from "./EditorPage";

test.describe("database editor", () => {
  const databaseSchema = {
    blocks: {
      title: "Blocks",
      properties: {
        block_id: { type: "number", readOnly: true },
        path: { type: "string" },
        name: { type: "string" },
        content: { type: "string" },
      },
    },
    pages: {
      title: "Pages",
      properties: {
        page_id: { type: "number", readOnly: true },
        name: { type: "string" },
        method: { type: "string" },
        pattern: { type: "string" },
        title: { type: "string" },
        template: { type: "string" },
        in_app: { type: "boolean", readOnly: true },
      },
    },
  };
  const databaseData: { [key: string]: Array<any> } = {
    blocks: [],
    pages: [],
  };

  test.beforeEach(async ({ page }) => {
    await page.goto("/yancy");
    await page.route("*/**/api", async (route) => {
      const json = databaseSchema;
      await route.fulfill({ json });
    });
    await page.route("*/**/api/*", async (route, request) => {
      const schemaName = request.url().split("/").slice(-1)[0];
      const json = databaseData[schemaName];
      await route.fulfill({ json: { items: json } });
    });
  });

  test.describe("database list", () => {
    test("lists all databases", async ({ page }) => {
      const editor = new EditorPage(page);
      await editor.databaseTabLabel.click();
      const databaseItems = editor.databaseTabPanel.locator("li");
      await expect(databaseItems).toHaveCount(
        Object.keys(databaseSchema).length,
      );
      for (const [i, text] of Object.keys(databaseSchema).sort().entries()) {
        await expect(databaseItems.nth(i)).toContainText(text);
      }
    });
  });

  test.describe("shows data", () => {
    test("lists some data", async ({ page }) => {
      databaseData["pages"] = [
        {
          page_id: 1,
          name: "index",
          method: "GET",
          pattern: "/",
          title: "Home Page",
          template: "index.html.ep",
          in_app: true,
        },
      ];

      const editor = new EditorPage(page);
      const table = await editor.openDatabaseEditorForTable("pages");

      await expect(table.locator("tbody tr")).toHaveCount(
        databaseData["pages"].length,
      );
    });
  });
});
