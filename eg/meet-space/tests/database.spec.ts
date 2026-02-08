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
  });
});
