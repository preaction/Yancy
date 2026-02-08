import { render, screen } from "@testing-library/svelte";
import { expect, test, describe, afterAll, afterEach, beforeAll } from "vitest";
import userEvent from "@testing-library/user-event";
import type { YancySchema } from "../../lib/Yancy/Editor/src/types.d.ts";

import DatabaseTable from "../../lib/Yancy/Editor/src/database-table.svelte";
import type { UserEvent } from "@testing-library/user-event/dist/cjs/setup/setup.js";
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

const schema = {
  "x-id-field": "schema_id",
  properties: {
    schema_id: {
      type: "integer",
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
  http.get<{ id?: string; schema: string }>(
    "./api/:schema/:id?",
    async ({ params }) => {
      if (params.id) {
        // Fetching a single item
        // TODO: Support x-id-field completely
        const item = data[params.schema].find(
          (item) => item.schema_id.toString() === params.id?.toString(),
        );
        if (!item) {
          return HttpResponse.json({ error: "Not found" }, { status: 404 });
        }
        return HttpResponse.json(item);
      }
      // Fetching a list
      // TODO: Pagination from query params
      return HttpResponse.json({ items: data[params.schema] });
    },
  ),
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

describe("DatabaseTable", () => {
  test("uses x-list-columns", async () => {
    const listColumns = ["name"];
    render(DatabaseTable, {
      schema: { ...schema, "x-list-columns": listColumns },
      src: "/api/schema",
    });
    const headers = await screen.findAllByRole("columnheader");
    expect(headers).toHaveLength(listColumns.length);
    expect(headers.at(0)).toHaveTextContent(/name/);
  });
});
