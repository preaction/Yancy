import { expect, Locator, FrameLocator, Page } from "@playwright/test";

export default class EditorPage {
  page: Page;

  contentTabLabel: Locator;
  contentTabPanel: Locator;
  contentFrame: Locator;
  contentDocument: FrameLocator;

  // Content Editor Toolbar
  textTagSelect: Locator;
  statusIcon: Locator;

  // Database editor
  databaseTabLabel: Locator;
  databaseTabPanel: Locator;
  databaseEditor: Locator;
  databaseItemEditForm: Locator;

  constructor(page: Page) {
    this.page = page;

    this.contentTabLabel = page.getByRole("button", { name: "Content" });
    this.contentTabPanel = page.getByRole("region", { name: "Content" });
    this.contentFrame = page.locator("#content-view");
    this.contentDocument = page.frameLocator("#content-view");
    this.statusIcon = page.locator(".status");
    this.textTagSelect = page.locator(".toolbar .text select[name=tag]");
    this.databaseTabLabel = page.getByRole("button", { name: "Database" });
    this.databaseTabPanel = page.getByRole("region", { name: "Database" });
    this.databaseEditor = page.getByRole("region", { name: "Database Editor" });
    this.databaseItemEditForm = page.getByRole("form", { name: "Edit Item" });
  }

  async openPage(url: string): Promise<void> {
    await this.contentFrame.evaluate(
      (e, url: string) => e.setAttribute("src", url),
      url,
    );
  }

  async waitForSave(): Promise<void> {
    await expect(this.statusIcon.getByTitle("Saved")).toBeVisible();
  }

  async openDatabaseEditorForTable(table: string): Promise<void> {
    await this.databaseTabLabel.click();
    await this.databaseTabPanel.getByRole("button", { name: table }).click();
  }

  databaseEditorTableFor(table: string): Locator {
    return this.page.getByRole("table", { name: table });
  }
}
