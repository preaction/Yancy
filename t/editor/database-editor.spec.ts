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
const data: { [key: string]: any[] } = {
  schema: [
    { schema_id: 1, name: "One" },
    { schema_id: 2, name: "Two" },
  ],
};

const handlers = [
  http.get("/api", () => {
    return HttpResponse.json({ schema });
  }),
  http.get<{ id?: string; schema: string }>(
    "/api/:schema/:id?",
    async ({ params }) => {
      if (!params.id) {
        // Fetching a list
        // TODO: Pagination from query params
        return HttpResponse.json({ items: data[params.schema] });
      }
      // Fetching a single item
      // TODO: Support x-id-field completely
      const item = data[params.schema].find(
        (item) => item.schema_id.toString() === params.id.toString(),
      );
      if (!item) {
        return HttpResponse.json({ error: "Not found" }, { status: 404 });
      }
      return HttpResponse.json(item);
    },
  ),
  http.post<{ id?: string; schema: string }>(
    "/api/:schema/:id?",
    async ({ request, params }) => {
      const postItem = (await request.clone().json()) as any;
      // TODO: Must validate the item against schema use "ajv" npm module

      if (!postItem) {
        return HttpResponse.json({ error: "No body" }, { status: 400 });
      }

      if (params.id) {
        // We're updating an existing item
        // TODO: Support x-id-field completely
        const idx = data[params.schema].findIndex(
          (item) => item.schema_id.toString() === params.id?.toString(),
        );
        if (idx < 0) {
          return HttpResponse.json({ error: "Not found" }, { status: 404 });
        }
        data[params.schema][idx] = Object.assign(
          data[params.schema][idx],
          postItem,
        );
        return HttpResponse.json(data[params.schema][idx], { status: 204 });
      }
      // We're adding a new item
      // TODO: Generate new autoinc ID
      const newItemId = data[params.schema].length;
      postItem.schema_id = newItemId;
      data[params.schema].push(postItem);
      return HttpResponse.arrayBuffer(new ArrayBuffer(newItemId), {
        status: 201,
      });
    },
  ),
  http.delete<{ id: string; schema: string }>(
    "/api/:schema/:id",
    async ({ params }) => {
      const idx = data[params.schema].findIndex(
        (item) => item.schema_id.toString() === params.id?.toString(),
      );
      if (idx < 0) {
        return HttpResponse.json({ error: "Not found" }, { status: 404 });
      }
      data[params.schema].splice(idx, 1);
      return HttpResponse.arrayBuffer(new ArrayBuffer(), { status: 204 });
    },
  ),
];

// XXX: We also need Yancy::Storage mock handlers

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
    render(DatabaseEditor, { src: "", schema: "schema" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    const editor = screen.getByRole("region", { name: "Database Editor" });
    expect(editor).toBeVisible();
    const table = screen.getByRole("table", { name: "schema" });
    expect(table).toBeVisible();
  });

  test("updates when schema changes", async () => {
    const { rerender } = render(DatabaseEditor, { src: "", schema: "" });
    rerender({ src: "", schema: "schema" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    const editor = screen.getByRole("region", { name: "Database Editor" });
    expect(editor).toBeVisible();
    const table = screen.getByRole("table", { name: "schema" });
    expect(table).toBeVisible();
  });

  test("can add new data rows", async () => {
    render(DatabaseEditor, { src: "", schema: "schema" });
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
    render(DatabaseEditor, { src: "", schema: "schema" });
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

  test("can cancel editing with no changes", async () => {
    render(DatabaseEditor, { src: "", schema: "schema" });
    await new Promise((resolve) => setTimeout(resolve, 0));
    const editor = screen.getByRole("region", { name: "Database Editor" });
    const editButton = screen.getAllByRole("button", { name: "Edit" })[0];
    await userEvent.click(editButton);

    const nameField = screen.getByRole("textbox", { name: "name" });
    await userEvent.type(nameField, " and then some");
    const cancelButton = screen.getByRole("button", { name: "Cancel" });
    await userEvent.click(cancelButton);

    const editDialog = screen.findByRole("dialog");
    expect(editDialog).rejects;
    expect(screen.getByRole("cell", { name: "One and more" })).toBeVisible();
  });
});
