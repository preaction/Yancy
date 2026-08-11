import {
  expect,
  type Locator,
  type FrameLocator,
  type Page,
} from "@playwright/test";

export default class EditorPage {
  page: Page;

  websiteTabLabel: Locator;
  websiteTabPanel: Locator;
  websiteFrame: Locator;
  websiteDocument: FrameLocator;

  // Content Editor Toolbar
  textTagSelect: Locator;
  statusIcon: Locator;

  constructor(page: Page) {
    this.page = page;

    this.websiteTabLabel = page.getByRole("heading", { name: "Website" });
    this.websiteTabPanel = page.getByRole("list", { name: "Website" });
    this.websiteFrame = page.locator("#content-view");
    this.websiteDocument = page.frameLocator("#content-view");
    this.statusIcon = page.locator(".status");
    this.textTagSelect = page.locator(".toolbar .text select[name=tag]");
  }

  async openPage(url: string): Promise<void> {
    await this.websiteFrame.evaluate(
      (e, url: string) => e.setAttribute("src", url),
      url,
    );
  }

  async waitForSave(): Promise<void> {
    await expect(this.statusIcon.getByTitle("Saved")).toBeVisible();
  }
}
