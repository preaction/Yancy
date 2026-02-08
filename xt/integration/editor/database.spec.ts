// XXX: This should be an e2e test and should NOT be mocking API requests...

import { test, expect } from "@playwright/test";
import DatabasePage from "../pages/DatabaseEditor";
import type { JSONSchema7 as JSONSchema } from "json-schema";

test.describe("database editor", () => {
  const databaseSchema: { [key: string]: JSONSchema } = {
    blocks: { type: "object", properties: {} },
    pages: { type: "object", properties: {} },
    situs: { type: "object", properties: {} },
  };
  const databaseData: { [key: string]: Array<any> } = {
    blocks: [],
    pages: [],
    situs: [],
  };

  test.beforeEach(async ({ page }) => {
    for (const key of Object.keys(databaseData)) {
      databaseData[key] = [];
    }

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
      const editor = new DatabasePage(page);
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
      databaseSchema["situs"] = {
        type: "object",
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
      };
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

      const editor = new DatabasePage(page);
      await editor.openTable("situs");
      const table = editor.tableFor("situs");

      const schemaColumns = Object.keys(
        databaseSchema["situs"].properties || {},
      );
      const columnHeadings = table.locator("thead th");
      await expect(columnHeadings).toHaveCount(schemaColumns.length + 1);
      for (const [i, text] of schemaColumns.entries()) {
        await expect(columnHeadings.nth(i + 1)).toContainText(text);
      }

      const tableRows = table.locator("tbody tr");
      await expect(tableRows).toHaveCount(databaseData["situs"].length);
      for (const [i, dataRow] of databaseData["situs"].entries()) {
        const tableRow = tableRows.nth(i);

        const editButton = tableRow.getByRole("button", { name: "Edit" });
        expect(editButton).toBeEnabled();

        const tableFields = tableRow.locator("td");
        for (const [j, col] of schemaColumns.entries()) {
          if (dataRow[col]) {
            await expect(tableFields.nth(j + 1)).toContainText(
              dataRow[col].toString(),
            );
          }
        }
      }
    });
  });

  test.describe("edits data", () => {
    test("shows form to add new data", async ({ page }) => {
      const editor = new DatabasePage(page);
      await editor.openTable("situs");
      await editor.addButton.click();

      const form = editor.itemEditForm;
      await expect(form).toBeVisible();
      await expect(form.getByRole("button", { name: "Save" })).toBeVisible();
      await expect(form.getByRole("button", { name: "Cancel" })).toBeVisible();
    });

    test("shows form to edit existing data", async ({ page }) => {
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

      const editor = new DatabasePage(page);
      await editor.openTable("situs");
      const table = editor.tableFor("situs");
      const tableRow = table.locator("tbody tr").first();
      await tableRow.getByRole("button", { name: "Edit" }).click();

      const form = editor.itemEditForm;
      await expect(form).toBeVisible();
      await expect(form.getByRole("button", { name: "Save" })).toBeVisible();
      await expect(form.getByRole("button", { name: "Cancel" })).toBeVisible();
    });
  });
});
