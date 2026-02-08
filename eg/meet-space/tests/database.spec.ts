import { test, expect } from "@playwright/test";
import DatabaseEditor from "../../../xt/integration/pages/DatabaseEditor";

test.describe("database editor", () => {
  test("create a calendar", async ({ page }) => {
    await page.goto("/yancy");
    const db = new DatabaseEditor(page);
    await db.openTable("calendars");
    await db.addButton.click();

    const form = db.itemEditForm;
    await expect(form).toBeVisible();
    await expect(form.getByLabel("calendar_id")).toBeDisabled();
    await expect(form.getByLabel("title")).toBeFocused();
    await expect(form.getByLabel("description")).toHaveJSProperty(
      "nodeName",
      "TEXTAREA",
    );

    await form.getByLabel("title").fill("Birthdays");
    await form
      .getByLabel("description")
      .fill("Upcoming birthday parties at MeetSpace");
    await form.getByRole("button", { name: "save" }).click();

    await expect(form).not.toBeVisible();
    const table = db.tableFor("calendars");
    await expect(table).toBeVisible();

    const headers = table.getByRole("columnheader");
    await expect(headers).toHaveCount(2);

    const newItem = table.getByRole("row", { name: "Birthdays" });
    await expect(newItem).toBeVisible();
    const cells = newItem.getByRole("cell");
    await expect(cells).toHaveCount(3);
    await expect(cells.nth(0)).toContainText("Birthdays");
    await expect(cells.nth(1)).toContainText(/Upcoming birthday parties/);
  });
});
