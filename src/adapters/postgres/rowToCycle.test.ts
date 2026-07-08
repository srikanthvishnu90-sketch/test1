import { describe, it, expect } from "vitest";
import { rowToCycle } from "./rowToCycle";

describe("rowToCycle", () => {
  it("maps a row to a Cycle, ISO-formatting a Date timestamp", () => {
    const cycle = rowToCycle({
      id: "abc",
      created_at: new Date("2026-07-07T12:00:00.000Z"),
      prediction: { items: [], predictedScore: 0.5 },
      outcome: { items: [] },
      calibration: {
        brier: 0.1,
        bias: 0,
        meanConfidence: 0.5,
        meanCorrect: 0.5,
        itemError: [],
      },
      item_reflections: [],
      score_reflection: null,
    });

    expect(cycle.id).toBe("abc");
    expect(cycle.createdAt).toBe("2026-07-07T12:00:00.000Z");
    expect(cycle.itemReflections).toEqual([]);
    expect(cycle.scoreReflection).toBeNull();
    expect(cycle.calibration.brier).toBe(0.1);
  });

  it("maps attached reflections and a string timestamp", () => {
    const cycle = rowToCycle({
      id: "x",
      created_at: "2026-01-01T00:00:00.000Z",
      prediction: {},
      outcome: {},
      calibration: {},
      item_reflections: [
        { causeId: "rushed", nextAction: "do it", dueDate: "2026-01-02" },
      ],
      score_reflection: { answers: { gap: "moved fast" } },
    });

    expect(cycle.createdAt).toBe("2026-01-01T00:00:00.000Z");
    expect(cycle.itemReflections).toHaveLength(1);
    expect(cycle.scoreReflection?.answers.gap).toBe("moved fast");
  });

  it("defaults missing reflection columns to [] and null", () => {
    const cycle = rowToCycle({
      id: "y",
      created_at: "2026-01-01T00:00:00.000Z",
      prediction: {},
      outcome: {},
      calibration: {},
      item_reflections: null,
      score_reflection: null,
    });
    expect(cycle.itemReflections).toEqual([]);
    expect(cycle.scoreReflection).toBeNull();
  });
});
