import { describe, it, expect } from "vitest";
import { createPrediction, probability } from "./prediction";

describe("probability", () => {
  it("accepts values within [0, 1]", () => {
    expect(probability(0)).toBe(0);
    expect(probability(0.5)).toBe(0.5);
    expect(probability(1)).toBe(1);
  });

  it("rejects values outside [0, 1] and non-finite numbers", () => {
    expect(() => probability(-0.01)).toThrow(RangeError);
    expect(() => probability(1.01)).toThrow(RangeError);
    expect(() => probability(Number.NaN)).toThrow(RangeError);
    expect(() => probability(Number.POSITIVE_INFINITY)).toThrow(RangeError);
  });
});

describe("createPrediction", () => {
  it("builds a prediction from valid input", () => {
    const p = createPrediction({
      items: [
        { itemId: "q1", confidence: 0.8 },
        { itemId: "q2", confidence: 0.4 },
      ],
      predictedScore: 0.6,
    });

    expect(p.items).toHaveLength(2);
    expect(p.items[0]).toEqual({ itemId: "q1", confidence: 0.8 });
    expect(p.predictedScore).toBe(0.6);
  });

  it("requires at least one item", () => {
    expect(() => createPrediction({ items: [], predictedScore: 0.5 })).toThrow(
      RangeError,
    );
  });

  it("rejects duplicate itemIds", () => {
    expect(() =>
      createPrediction({
        items: [
          { itemId: "q1", confidence: 0.5 },
          { itemId: "q1", confidence: 0.6 },
        ],
        predictedScore: 0.5,
      }),
    ).toThrow(/Duplicate/);
  });

  it("rejects empty itemIds", () => {
    expect(() =>
      createPrediction({ items: [{ itemId: "  ", confidence: 0.5 }], predictedScore: 0.5 }),
    ).toThrow(RangeError);
  });

  it("rejects out-of-range confidences", () => {
    expect(() =>
      createPrediction({ items: [{ itemId: "q1", confidence: 1.5 }], predictedScore: 0.5 }),
    ).toThrow(RangeError);
  });

  it("rejects out-of-range predicted score", () => {
    expect(() =>
      createPrediction({ items: [{ itemId: "q1", confidence: 0.5 }], predictedScore: 2 }),
    ).toThrow(RangeError);
  });
});
