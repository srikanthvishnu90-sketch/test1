import { describe, it, expect } from "vitest";
import {
  createScoreReflection,
  questionsFor,
  SCORE_QUESTIONS,
} from "./scoreReflection";

describe("SCORE_QUESTIONS", () => {
  it("is a short series with unique ids and no empty prompts", () => {
    expect(SCORE_QUESTIONS.length).toBeGreaterThanOrEqual(2);
    expect(SCORE_QUESTIONS.length).toBeLessThanOrEqual(5); // keep it short for engagement
    const ids = SCORE_QUESTIONS.map((q) => q.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const q of SCORE_QUESTIONS) expect(q.prompt.trim().length).toBeGreaterThan(0);
  });
});

describe("questionsFor", () => {
  it("drops miss-specific questions when nothing was missed", () => {
    const all = questionsFor(true);
    const some = questionsFor(false);
    expect(some.length).toBeLessThan(all.length);
    expect(some.every((q) => !q.needsMiss)).toBe(true);
  });
});

describe("createScoreReflection", () => {
  it("trims answers and keeps only known question ids", () => {
    const r = createScoreReflection({
      gap: "  I rushed it.  ",
      unknownId: "should be dropped",
    });
    expect(r.answers.gap).toBe("I rushed it.");
    expect(r.answers.unknownId).toBeUndefined();
  });

  it("drops blank answers", () => {
    const r = createScoreReflection({ plan: "   " });
    expect(Object.keys(r.answers)).toHaveLength(0);
  });
});
