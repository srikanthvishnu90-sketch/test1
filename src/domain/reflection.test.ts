import { describe, it, expect } from "vitest";
import { createReflection, causeLabel } from "./reflection";

describe("createReflection", () => {
  it("builds a reflection from a controllable cause + concrete action", () => {
    const r = createReflection({
      causeId: "rushed",
      nextAction: "Redo questions 2–4 slowly and check each step.",
    });
    expect(r.causeId).toBe("rushed");
    expect(r.nextAction).toBe("Redo questions 2–4 slowly and check each step.");
  });

  it("rejects causes outside the controllable/specific taxonomy", () => {
    expect(() =>
      createReflection({ causeId: "im-bad-at-math", nextAction: "Study more." }),
    ).toThrow(RangeError);
  });

  it("rejects an empty next action", () => {
    expect(() =>
      createReflection({ causeId: "misread", nextAction: "  " }),
    ).toThrow(RangeError);
  });

  it("captures a free-text reason when the cause is 'other'", () => {
    const r = createReflection({
      causeId: "other",
      otherText: "I second-guessed a right answer and switched it.",
      nextAction: "Trust my first read unless I find a real reason.",
    });
    expect(r.causeId).toBe("other");
    expect(r.otherText).toBe("I second-guessed a right answer and switched it.");
  });

  it("requires the free-text reason when the cause is 'other'", () => {
    expect(() =>
      createReflection({ causeId: "other", otherText: "  ", nextAction: "Do the thing." }),
    ).toThrow(RangeError);
  });
});

describe("causeLabel", () => {
  it("returns the label for a known cause", () => {
    expect(causeLabel("guessed")).toBe("I guessed instead of reasoning it through");
  });
});
