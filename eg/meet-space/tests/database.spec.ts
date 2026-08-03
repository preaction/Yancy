import { test, expect } from "@playwright/test";
import DatabaseEditor from "../../../xt/integration/pages/DatabaseEditor";
import path from "node:path";

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

  test("create a news post", async ({ request, page }) => {
    await page.goto("/yancy");
    const db = new DatabaseEditor(page);
    await db.openTable("news_posts");
    await db.addButton.click();

    const form = db.itemEditForm;
    await expect(form).toBeVisible();
    await expect(form.getByLabel("title")).toBeFocused();

    await form.getByLabel("title").fill("Grand Opening");
    await form
      .getByLabel("banner_image")
      .setInputFiles(path.join(import.meta.dirname, "data", "banner.webp"));
    await form.getByRole("button", { name: "save" }).click();

    // Check that if Slug was not filled in, we should see an error
    await expect(form.getByRole("alert")).toHaveAccessibleDescription("Error");
    await expect(form.getByLabel("slug")).toHaveAccessibleErrorMessage(
      "Missing property.",
    );

    await form.getByLabel("slug").fill("grand-opening");
    await form.getByRole("button", { name: "save" }).click();

    await expect(form).not.toBeVisible();
    const table = db.tableFor("news_posts");
    await expect(table).toBeVisible();

    const headers = table.getByRole("columnheader");
    await expect(headers).toHaveCount(3);

    const newItem = table.getByRole("row", { name: "Grand Opening" });
    await expect(newItem).toBeVisible();
    const cells = newItem.getByRole("cell");
    await expect(cells).toHaveCount(4);
    await expect(cells.nth(1)).toContainText("Grand Opening");

    // Now look at the news post on the site
    await page.goto("/news");
    const newsLink = page.getByRole("link", { name: "Grand Opening" });
    await expect(newsLink).toBeVisible();
    await newsLink.click();

    const bannerImage = page.locator("img");
    await expect(bannerImage).toBeVisible();
    const bannerSrc = await bannerImage.getAttribute("src");
    expect(bannerSrc).not.toBeNull();
    if (bannerSrc) {
      await expect(request.get(bannerSrc)).resolves.toBeOK();
    }
  });

  test("create an event", async ({ request, page }) => {
    await page.goto("/yancy");
    const db = new DatabaseEditor(page);
    await db.openTable("events");
    await db.addButton.click();

    const form = db.itemEditForm;
    await expect(form).toBeVisible();
    await expect(form.getByLabel("title")).toBeFocused();
    await form.getByLabel("title").fill("Grand Opening");

    // Add some photos
    const photos = await form.getByRole("group", { name: "photos" });
    await photos.getByRole("button", { name: "add" }).click();
    await photos
      .getByTestId("y-file-field")
      .setInputFiles(path.join(import.meta.dirname, "data", "banner.webp"));

    // Check that if Slug was not filled in, we should see an error
    await form.getByRole("button", { name: "save" }).click();
    await expect(form.getByRole("alert")).toHaveAccessibleDescription("Error");
    await expect(form.getByLabel("slug")).toHaveAccessibleErrorMessage(
      "Missing property.",
    );

    await form.getByLabel("slug").fill("grand-opening");
    await form.getByRole("button", { name: "save" }).click();

    await expect(form).not.toBeVisible();
    const table = db.tableFor("events");
    await expect(table).toBeVisible();

    const headers = table.getByRole("columnheader");
    await expect(headers).toHaveCount(5);

    const newItem = table.getByRole("row", { name: "Grand Opening" });
    await expect(newItem).toBeVisible();
    const cells = newItem.getByRole("cell");
    await expect(cells).toHaveCount(6);
    await expect(cells.nth(1)).toContainText("Grand Opening");

    // Now look at the event on the site
    await page.goto("/events");
    const newsLink = page.getByRole("link", { name: "Grand Opening" });
    await expect(newsLink).toBeVisible();
    await newsLink.click();

    // Look for photos
    const photoImage = page.locator("img");
    await expect(photoImage).toBeVisible();
    const photoSrc = await photoImage.getAttribute("src");
    expect(photoSrc).toMatch(/banner\.webp/);
    if (photoSrc) {
      await expect(request.get(photoSrc)).resolves.toBeOK();
    }
  });
});
