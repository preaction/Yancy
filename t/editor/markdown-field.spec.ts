import { render, screen } from "@testing-library/svelte";
import userEvent from "@testing-library/user-event";
import { expect, test, describe } from "vitest";

import MarkdownField from "../../lib/Yancy/Editor/src/markdown-field.svelte";

describe("MarkdownField", () => {
  test("shows markdown field", async () => {
    render(MarkdownField, {
      id: "mdfield",
      value: "# heading\n",
      oninput: () => {},
    });
    const field = screen.getByPlaceholderText("Markdown content");
    expect(field).toBeInstanceOf(HTMLTextAreaElement);
    expect(field).toHaveValue("# heading\n");

    const button = screen.getByText("Preview");
    expect(button).toBeVisible();
    expect(button).toHaveAttribute("type", "button");
  });
  test("preview button shows rendered markdown", async () => {
    render(MarkdownField, {
      id: "mdfield",
      value: "# heading\n\nbody",
      oninput: () => {},
    });
    screen.getByText("Preview").click();
    const preview = screen.getByTestId("markdown-preview");
    expect(preview).toBeVisible();
    expect(preview).toContainHTML("<h1>heading</h1>");
  });
  test("value is updated", async () => {
    const user = userEvent.setup();
    let value = "# heading\n\nbody";
    let newValue = "";
    render(MarkdownField, {
      id: "mdfield",
      value,
      oninput: (v) => {
        newValue = v;
      },
    });
    const field = screen.getByPlaceholderText("Markdown content");
    await user.type(field, "\n\n## second heading\n");
    expect(newValue).toMatch(/## second heading/);
  });
});
