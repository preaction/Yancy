import { render, screen } from "@testing-library/svelte";
import userEvent from "@testing-library/user-event";
import { expect, test, describe, beforeAll, afterAll, afterEach } from "vitest";
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

const handlers = [
  http.get("./api", () => {
    return HttpResponse.json({
      schema: {
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
      },
    });
  }),
  http.get("./api/schema", () => {
    return HttpResponse.json({
      items: [
        { schema_id: 1, name: "One" },
        { schema_id: 2, name: "Two" },
      ],
    });
  }),
];
const server = setupServer(...handlers);
beforeAll(() => {
  server.listen();
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
});
