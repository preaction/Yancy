import { type Locator, type Page } from "@playwright/test";

export default class DatabaseEditor {
  page: Page;

  // Database editor
  databaseTabLabel: Locator;
  databaseTabPanel: Locator;
  editor: Locator;
  itemEditForm: Locator;
  addButton: Locator;

  constructor(page: Page) {
    this.page = page;

    this.databaseTabLabel = page.getByRole("button", { name: "Database" });
    this.databaseTabPanel = page.getByRole("region", { name: "Database" });
    this.editor = page.getByRole("region", { name: "Database Editor" });
    this.itemEditForm = page.getByRole("form", { name: "Edit Item" });
    this.addButton = this.editor.getByRole("button", { name: "Add" });
  }

  async openTable(table: string): Promise<void> {
    await this.databaseTabLabel.click();
    await this.databaseTabPanel.getByRole("link", { name: table }).click();
  }

  tableFor(table: string): Locator {
    return this.page.getByRole("table", { name: table });
  }
}
