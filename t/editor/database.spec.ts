import { test, expect, Locator } from "@playwright/test";
import EditorPage from "./EditorPage";
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

      const editor = new EditorPage(page);
      await editor.openDatabaseEditorForTable("situs");
      const table = editor.databaseEditorTableFor("situs");

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
      const editor = new EditorPage(page);
      await editor.openDatabaseEditorForTable("situs");
      await editor.databaseEditor.getByRole("button", { name: "Add" }).click();

      const form = editor.databaseItemEditForm;
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

      const editor = new EditorPage(page);
      await editor.openDatabaseEditorForTable("situs");
      const table = editor.databaseEditorTableFor("situs");
      const tableRow = table.locator("tbody tr").first();
      await tableRow.getByRole("button", { name: "Edit" }).click();

      const form = editor.databaseItemEditForm;
      await expect(form).toBeVisible();
      await expect(form.getByRole("button", { name: "Save" })).toBeVisible();
      await expect(form.getByRole("button", { name: "Cancel" })).toBeVisible();
    });

    test.describe.only("shows correct input for data column", () => {
      // XXX: It'd be much nicer if we didn't need the entire Yancy editor around
      // to be able to test the inner workings of the edit-form element.
      type TestCase = {
        title: string;
        schema: JSONSchema;
        value: any;
        check: (testCase: TestCase, form: Locator) => Promise<void>;
      };
      const cases: Array<TestCase> = [
        {
          title: "shows correct input for plain string",
          schema: { type: "string" },
          value: "stringValue",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows correct input for textarea string",
          schema: { type: "string", format: "textarea" },
          value: "stringValue",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "TEXTAREA");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows correct input for string enum",
          schema: { type: "string", enum: ["enumOne", "enumTwo"] },
          value: "enumTwo",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "SELECT");
            await expect(field).toHaveValue(testCase.value);
            await expect(field.locator("option:nth-child(1)")).toHaveText(
              "enumOne",
            );
            await expect(field.locator("option:nth-child(2)")).toHaveText(
              "enumTwo",
            );
          },
        },

        {
          title: "shows correct input for boolean",
          schema: { type: "boolean" },
          value: "true",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "checkbox");
            await expect(field).toBeChecked();
          },
        },

        {
          title: "shows correct input for boolean (false)",
          schema: { type: "boolean" },
          value: "false",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "checkbox");
            await expect(field).not.toBeChecked();
          },
        },

        {
          title: "shows correct input for integer",
          schema: { type: "integer" },
          value: "945",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "number");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows correct input for number",
          schema: { type: "number" },
          value: "9.23",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "number");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows correct input for date",
          schema: { type: "string", format: "date" },
          value: "2025-01-01",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "date");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows correct input for date-time",
          schema: { type: "string", format: "date-time" },
          value: "2025-01-01T01:20:30",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "datetime-local");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows correct input for email",
          schema: { type: "string", format: "email" },
          value: "example@example.com",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "email");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows correct input for url",
          schema: { type: "string", format: "url" },
          value: "https://example.com",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "url");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows correct input for tel",
          schema: { type: "string", format: "tel" },
          value: "+13125550199",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveAttribute("type", "tel");
            await expect(field).toHaveValue(testCase.value);
          },
        },

        {
          title: "shows readOnly value",
          // TODO: Each field has its own readonly-style
          schema: { type: "string", readOnly: true },
          value: "readOnly",
          check: async (testCase: TestCase, form: Locator): Promise<void> => {
            const field = form.getByLabel("fieldName");
            await expect(field).toBeVisible();
            await expect(field).toHaveJSProperty("tagName", "INPUT");
            await expect(field).toHaveValue(testCase.value);
            await expect(field).toBeDisabled();
          },
        },
      ];

      for (const testCase of cases) {
        test(testCase.title, async ({ page }) => {
          databaseSchema["situs"] = {
            type: "object",
            properties: {
              fieldName: testCase.schema,
            },
          };
          databaseData["situs"] = [
            {
              fieldName: testCase.value,
            },
          ];

          const editor = new EditorPage(page);
          await editor.openDatabaseEditorForTable("situs");
          const table = editor.databaseEditorTableFor("situs");
          const tableRow = table.locator("tbody tr").first();
          await tableRow.getByRole("button", { name: "Edit" }).click();

          const form = editor.databaseItemEditForm;
          await testCase.check(testCase, form);
        });
      }
    });
  });
});
