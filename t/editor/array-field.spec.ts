import { render, screen } from "@testing-library/svelte";
import { expect, test, describe, afterAll, afterEach, beforeAll } from "vitest";
import userEvent from "@testing-library/user-event";
import type { YancySchema } from "../../lib/Yancy/Editor/src/types.d.ts";

import ArrayField from "../../lib/Yancy/Editor/src/array-field.svelte";
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

describe("ArrayField", () => {
  // TODO: Test that onchange works as expected

  test("shows array of strings", async ({}) => {
    const schema: YancySchema = {
      type: "array",
      items: {
        type: "string",
      },
    };
    const value = ["one", "two", "three"];
    render(ArrayField, { name: "array", value, schema, storage: "./" });

    // Expect all items to be showing as input textboxes
    const field = screen.getAllByRole("textbox");
    expect(field).toHaveLength(value.length);
    expect(field[0]).toHaveValue(value[0]);
    expect(field[1]).toHaveValue(value[1]);
    expect(field[2]).toHaveValue(value[2]);

    // Expect buttons to add, re-order, and delete
    // TODO
    // XXX: Some field types should show all items as inputs. Text input is one
    // of these.
  });

  test("shows array of files", async ({}) => {
    const schema: YancySchema = {
      type: "array",
      items: {
        type: "string",
        format: "filepath",
      },
    };
    const value = ["foo.txt", "bar.gif", "baz.pdf"];
    render(ArrayField, { name: "array", value, schema, storage: "./" });

    // Expect all items to be showing
    const field = screen.getAllByTestId("y-file-field");
    expect(field).toHaveLength(value.length);
    // FIXME: This presumes the structure of the FileField component
    expect(field[0].previousElementSibling).toHaveTextContent(value[0]);
    expect(field[1].previousElementSibling).toHaveTextContent(value[1]);
    expect(field[2].previousElementSibling).toHaveTextContent(value[2]);

    // Expect buttons to add, re-order, and delete
    // TODO
    // XXX: Some field types should only show one input to add new elements.
    // File input should be one of these.
  });

  test("shows array of images", async ({}) => {
    const schema: YancySchema = {
      type: "array",
      items: {
        type: "string",
        format: "filepath",
        "x-mime-type": "image/*",
      },
    };
    const value = ["foo.jpg", "bar.gif", "baz.webp"];
    render(ArrayField, { name: "array", value, schema, storage: "./" });

    // Expect all items to be showing
    const field = screen.getAllByTestId("y-file-field");
    expect(field).toHaveLength(value.length);
    // FIXME: This presumes the structure of the FileField component
    expect(field[0].previousElementSibling).toHaveTextContent(value[0]);
    expect(field[1].previousElementSibling).toHaveTextContent(value[1]);
    expect(field[2].previousElementSibling).toHaveTextContent(value[2]);

    // Expect buttons to add, re-order, and delete
    // TODO
    // XXX: Some field types should only show one input to add new elements.
    // File input should be one of these.
  });
});
