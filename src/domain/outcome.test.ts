import { describe, it, expect } from "vitest";
import { createOutcome } from "./outcome";

describe("createOutcome", () => {
  it("builds an outcome from valid input", () => {
    const o = createOutcome({
      items: [
        { itemId: "q1", correct: true },
        { itemId: "q2", correct: false },
      ],
    });
    expect(o.items).toHaveLength(2);
    expect(o.items[0]).toEqual({ itemId: "q1", correct: true });
  });

  it("requires at least one item", () => {
    expect(() => createOutcome({ items: [] })).toThrow(RangeError);
  });

  it("rejects duplicate itemIds", () => {
    expect(() =>
      createOutcome({
        items: [
          { itemId: "q1", correct: true },
          { itemId: "q1", correct: false },
        ],
      }),
    ).toThrow(/Duplicate/);
  });

  it("rejects empty itemIds", () => {
    expect(() => createOutcome({ items: [{ itemId: " ", correct: true }] })).toThrow(
      RangeError,
    );
  });
});
