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
    { schema_id: 3, name: "Three" },
    { schema_id: 4, name: "Four" },
    { schema_id: 5, name: "Five" },
    { schema_id: 6, name: "Six" },
  ],
};

const handlers = [
  http.get<{ id?: string; schema: string }>(
    "./api/:schema/:id?",
    async ({ params, request }) => {
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
      const url = new URL(request.url);
      const limit = parseInt(url.searchParams.get("$limit") ?? "10");
      const page = parseInt(url.searchParams.get("$page") ?? "1");
      const start = (page - 1) * limit;
      const items = data[params.schema].slice(
        start,
        Math.min(start + limit, data[params.schema].length),
      );
      return HttpResponse.json({
        items,
        total: data[params.schema].length,
      });
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

  describe("pagination", () => {
    test("disabled when only one page", async () => {
      render(DatabaseTable, {
        schema,
        src: "/api/schema",
      });
      const nav = await screen.findByRole("navigation", { name: "Pagination" });
      expect(nav).toBeVisible();
      const prev = screen.getByRole("button", { name: "Previous" });
      expect(prev).toBeVisible();
      expect(prev).toHaveAttribute("aria-disabled", "true");
      const next = screen.getByRole("button", { name: "Next" });
      expect(next).toBeVisible();
      expect(next).toHaveAttribute("aria-disabled", "true");
    });

    test("can go to next page", async () => {
      render(DatabaseTable, {
        schema,
        src: "/api/schema",
        query: { $limit: 2 },
      });
      const next = await screen.findByRole("button", { name: "Next" });
      expect(next).toBeVisible();
      expect(next).toHaveAttribute("aria-disabled", "false");
    });

    test("can go to previous page", async () => {
      render(DatabaseTable, {
        schema,
        src: "/api/schema",
        query: { $limit: 2, $page: 2 },
      });
      const prev = await screen.findByRole("button", { name: "Previous" });
      expect(prev).toBeVisible();
      expect(prev).toHaveAttribute("aria-disabled", "false");
    });
  });
});
