import "@testing-library/jest-dom/vitest";
import { vi } from "vitest";

// Add some stubs to JSDOM for Tiptap
Range.prototype.getBoundingClientRect = () => ({
  bottom: 0,
  height: 0,
  left: 0,
  right: 0,
  top: 0,
  width: 0,
  x: 0,
  y: 0,
  toJSON: vi.fn(),
});
Range.prototype.getClientRects = () => ({
  item: () => null,
  length: 0,
  [Symbol.iterator]: vi.fn(),
});
Document.prototype.elementFromPoint = vi.fn();
