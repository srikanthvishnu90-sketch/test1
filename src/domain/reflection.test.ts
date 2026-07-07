import { describe, it, expect } from "vitest";
import { createReflection, causeLabel } from "./reflection";

describe("createReflection", () => {
  it("builds a reflection from a controllable cause + concrete action + date", () => {
    const r = createReflection({
      causeId: "rushed",
      nextAction: "Redo questions 2–4 slowly and check each step.",
      dueDate: "2026-07-10",
    });
    expect(r.causeId).toBe("rushed");
    expect(r.nextAction).toBe("Redo questions 2–4 slowly and check each step.");
    expect(r.dueDate).toBe("2026-07-10");
  });

  it("rejects causes outside the controllable/specific taxonomy", () => {
    expect(() =>
      createReflection({
        causeId: "im-bad-at-math",
        nextAction: "Study more.",
        dueDate: "2026-07-10",
      }),
    ).toThrow(RangeError);
  });

  it("rejects an empty next action", () => {
    expect(() =>
      createReflection({ causeId: "misread", nextAction: "  ", dueDate: "2026-07-10" }),
    ).toThrow(RangeError);
  });

  it("rejects an invalid due date", () => {
    expect(() =>
      createReflection({ causeId: "misread", nextAction: "Review it.", dueDate: "next week" }),
    ).toThrow(RangeError);
  });
});

describe("causeLabel", () => {
  it("returns the label for a known cause", () => {
    expect(causeLabel("guessed")).toBe("I guessed instead of reasoning it through");
  });
});
