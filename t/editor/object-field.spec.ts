import { render, screen } from "@testing-library/svelte";
import { expect, test, describe, afterAll, afterEach, beforeAll } from "vitest";
import userEvent from "@testing-library/user-event";
import type { YancySchema } from "../../lib/Yancy/Editor/src/types.d.ts";

import ObjectField from "../../lib/Yancy/Editor/src/object-field.svelte";
import type { UserEvent } from "@testing-library/user-event/dist/cjs/setup/setup.js";
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

const handlers = [
  http.put("./storage/:id", () => {
    return HttpResponse.arrayBuffer(new ArrayBuffer(), { status: 201 });
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

describe("ObjectField", () => {
  // TODO: Test that onchange works as expected

  test("shows fields in x-order", async ({}) => {
    const schema: YancySchema = {
      type: "object",
      properties: {
        last: {
          type: "string",
          "x-order": 3,
        },
        unordered: {
          type: "string",
        },
        first: {
          type: "string",
          "x-order": 1,
        },
        middle: {
          type: "string",
          "x-order": 2,
        },
      },
    };
    render(ObjectField, { schema, storage: "./" });
    expect(screen.getByLabelText("first")).toAppearBefore(
      screen.getByLabelText("middle"),
    );
    expect(screen.getByLabelText("middle")).toAppearBefore(
      screen.getByLabelText("last"),
    );
    expect(screen.getByLabelText("unordered")).toAppearAfter(
      screen.getByLabelText("last"),
    );
  });
});
