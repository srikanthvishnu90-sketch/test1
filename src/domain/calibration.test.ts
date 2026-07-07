import { describe, it, expect } from "vitest";
import { createPrediction } from "./prediction";
import { createOutcome } from "./outcome";
import { calibrate } from "./calibration";

describe("calibrate", () => {
  it("scores perfect calibration as brier 0, bias 0", () => {
    const prediction = createPrediction({
      items: [
        { itemId: "q1", confidence: 1 },
        { itemId: "q2", confidence: 0 },
      ],
      predictedScore: 0.5,
    });
    const outcome = createOutcome({
      items: [
        { itemId: "q1", correct: true },
        { itemId: "q2", correct: false },
      ],
    });

    const c = calibrate(prediction, outcome);
    expect(c.brier).toBeCloseTo(0, 10);
    expect(c.bias).toBeCloseTo(0, 10);
    expect(c.meanConfidence).toBeCloseTo(0.5, 10);
    expect(c.meanCorrect).toBeCloseTo(0.5, 10);
  });

  it("reports positive bias when overconfident", () => {
    const prediction = createPrediction({
      items: [
        { itemId: "q1", confidence: 0.9 },
        { itemId: "q2", confidence: 0.9 },
      ],
      predictedScore: 0.9,
    });
    const outcome = createOutcome({
      items: [
        { itemId: "q1", correct: true },
        { itemId: "q2", correct: false },
      ],
    });

    const c = calibrate(prediction, outcome);
    expect(c.brier).toBeCloseTo(0.41, 10); // (0.01 + 0.81) / 2
    expect(c.bias).toBeCloseTo(0.4, 10); // 0.9 - 0.5
    expect(c.bias).toBeGreaterThan(0);
  });

  it("reports negative bias when underconfident", () => {
    const prediction = createPrediction({
      items: [{ itemId: "q1", confidence: 0.2 }],
      predictedScore: 0.2,
    });
    const outcome = createOutcome({ items: [{ itemId: "q1", correct: true }] });

    const c = calibrate(prediction, outcome);
    expect(c.bias).toBeLessThan(0);
  });

  it("throws when the item sets differ", () => {
    const prediction = createPrediction({
      items: [{ itemId: "q1", confidence: 0.5 }],
      predictedScore: 0.5,
    });
    const outcome = createOutcome({ items: [{ itemId: "qX", correct: true }] });

    expect(() => calibrate(prediction, outcome)).toThrow(RangeError);
  });
});
