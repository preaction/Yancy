import { render, screen } from "@testing-library/svelte";
import userEvent from "@testing-library/user-event";
import {
  expect,
  test,
  describe,
  beforeAll,
  afterAll,
  afterEach,
  vi,
} from "vitest";
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

// Until https://github.com/jsdom/jsdom/issues/3294 is fixed...
beforeAll(() => {
  HTMLDialogElement.prototype.show = vi.fn();
  HTMLDialogElement.prototype.showModal = vi.fn();
  HTMLDialogElement.prototype.close = vi.fn();
});

const schema = {
  "x-id-field": "schema_id",
  properties: {
    schema_id: {
      type: "number",
      readOnly: true,
    },
    name: {
      type: "string",
    },
  },
};
const items = [
  { schema_id: 1, name: "One" },
  { schema_id: 2, name: "Two" },
];

const handlers = [
  http.get("./api", () => {
    return HttpResponse.json({ schema });
  }),
  http.get("./api/schema", () => {
    return HttpResponse.json({ items });
  }),
  http.post("./api/schema/", () => {
    // XXX: Make this actually edit the items
    items.push({ schema_id: 3, name: "Three" });
    return HttpResponse.json({ schema_id: 3 });
  }),
  http.post("./api/schema/1", () => {
    // XXX: Make this actually edit the items
    items[0].name = "One and more";
    return HttpResponse.arrayBuffer(new ArrayBuffer(), { status: 204 });
  }),
];
const server = setupServer(...handlers);
beforeAll(() => {
  server.listen({ onUnhandledRequest: "error" });
});
afterEach(() => {
  server.resetHandlers();
});
afterAll(() => {
  server.close();
});

import DatabaseEditor from "../../lib/Yancy/Editor/src/database-editor.svelte";

describe("DatabaseEditor", () => {
  test("fetches schema and data", async () => {
    render(DatabaseEditor, { schema: "schema" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    const editor = screen.getByRole("region", { name: "Database Editor" });
    expect(editor).toBeVisible();
    const table = screen.getByRole("table", { name: "schema" });
    expect(table).toBeVisible();
  });

  test("updates when schema changes", async () => {
    const { rerender } = render(DatabaseEditor);
    rerender({ schema: "schema" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    const editor = screen.getByRole("region", { name: "Database Editor" });
    expect(editor).toBeVisible();
    const table = screen.getByRole("table", { name: "schema" });
    expect(table).toBeVisible();
  });

  test("can add new data rows", async () => {
    render(DatabaseEditor, { schema: "schema" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    const editor = screen.getByRole("region", { name: "Database Editor" });
    expect(editor).toBeVisible();
    const addButton = screen.getByRole("button", { name: "Add" });
    expect(addButton).toBeVisible();
    await userEvent.click(addButton);
    const editDialog = screen.getByRole("dialog");
    expect(editDialog).toBeVisible();
    const nameField = screen.getByRole("textbox", { name: "name" });
    expect(nameField).toHaveValue("");
    await userEvent.type(nameField, "Three");
    const saveButton = screen.getByRole("button", { name: "Save" });
    await userEvent.click(saveButton);
    expect(editDialog).not.toBeVisible();
    expect(screen.getByRole("cell", { name: "Three" })).toBeVisible();
  });

  test("can edit existing data rows", async () => {
    render(DatabaseEditor, { schema: "schema" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    const editor = screen.getByRole("region", { name: "Database Editor" });
    expect(editor).toBeVisible();
    const editButton = screen.getAllByRole("button", { name: "Edit" })[0];
    expect(editButton).toBeVisible();
    await userEvent.click(editButton);

    const editDialog = screen.getByRole("dialog");
    expect(editDialog).toBeVisible();
    const nameField = screen.getByRole("textbox", { name: "name" });
    expect(nameField).toHaveValue("One");
    await userEvent.type(nameField, " and more");
    const saveButton = screen.getByRole("button", { name: "Save" });
    await userEvent.click(saveButton);

    expect(editDialog).not.toBeVisible();
    expect(screen.getByRole("cell", { name: "One and more" })).toBeVisible();
  });
});
