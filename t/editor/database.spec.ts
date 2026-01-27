import { test, expect } from "@playwright/test";
import EditorPage from "./EditorPage";

test.describe("database editor", () => {
  const databaseSchema = {
    situs: {
      properties: {
        situs_id: { type: "number", readOnly: true },
        name: { type: "string" },
        street_number: { type: "number", format: "integer" },
        street_dir: { type: "string", enum: ["", "N", "E", "S", "W"] },
        street_name: { type: "string" },
        street_type: { type: "string", enum: ["ST", "AVE", "BLVD"] },
        jurisdiction: { type: "string" },
        legal_description: { type: "string", format: "textarea" },
      },
    },
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
    situs: [],
  };

  test.beforeEach(async ({ page }) => {
    await page.route("*/**/api", async (route) => {
      const json = databaseSchema;
      await route.fulfill({ json });
    });
    await page.route("*/**/api/*", async (route, request) => {
      const pathParts = request.url().split("/");
      const [schemaName, ...idParts] = pathParts.slice(
        pathParts.indexOf("api") + 1,
      );
      if (request.method() == "GET") {
        const json = databaseData[schemaName];
        if (idParts.length) {
          // XXX: Get a single item
        } else {
          // TODO: Filters
          // TODO: Pagination
          await route.fulfill({ json: { items: json } });
        }
      } else if (request.method() == "POST" || request.method() == "PUT") {
        // XXX: Create or update an item
      } else if (request.method() == "DELETE") {
        // XXX: Delete an item
      }
    });
    await page.goto("/yancy");
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
        await expect(databaseItems.nth(i)).toContainText(text, {
          ignoreCase: true,
        });
      }
    });
  });

  test.describe("shows data", () => {
    test("lists some data", async ({ page }) => {
      databaseData["situs"] = [
        {
          situs_id: 1,
          name: "index",
          street_number: 123,
          street_dir: "N",
          street_name: "MAIN",
          street_type: "ST",
          jurisdiction: "City of Oshkosh",
        },
      ];

      const editor = new EditorPage(page);
      const table = await editor.openDatabaseEditorForTable("situs");

      const schemaColumns = Object.keys(databaseSchema["situs"].properties);
      const columnHeadings = table.locator("thead th");
      await expect(columnHeadings).toHaveCount(schemaColumns.length);
      for (const [i, text] of schemaColumns.entries()) {
        await expect(columnHeadings.nth(i)).toContainText(text);
      }

      const tableRows = table.locator("tbody tr");
      await expect(tableRows).toHaveCount(databaseData["situs"].length);
      for (const [i, dataRow] of databaseData["situs"].entries()) {
        const tableFields = tableRows.nth(i).locator("td");
        for (const [j, col] of schemaColumns.entries()) {
          if (dataRow[col]) {
            await expect(tableFields.nth(j)).toContainText(
              dataRow[col].toString(),
            );
          }
        }
      }
    });
  });
});
