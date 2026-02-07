import { test, expect } from "@playwright/test";

test.describe("site content", () => {
  test("main page content", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("navigation", { name: "Main" })).toBeVisible();
  });
});
