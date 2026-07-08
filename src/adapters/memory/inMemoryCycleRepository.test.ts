import { describe, it, expect } from "vitest";
import { InMemoryCycleRepository } from "./inMemoryCycleRepository";
import { createPrediction } from "@/domain/prediction";
import { createOutcome } from "@/domain/outcome";
import { calibrate } from "@/domain/calibration";
import type { NewCycle } from "@/domain/cycle";

function sampleCycle(): NewCycle {
  const prediction = createPrediction({
    items: [{ itemId: "q1", confidence: 0.8 }],
    predictedScore: 0.8,
  });
  const outcome = createOutcome({ items: [{ itemId: "q1", correct: true }] });
  return {
    prediction,
    outcome,
    calibration: calibrate(prediction, outcome),
    itemReflections: [],
    scoreReflection: null,
  };
}

describe("InMemoryCycleRepository", () => {
  it("saves a cycle and assigns an id + timestamp", async () => {
    const repo = new InMemoryCycleRepository();
    const saved = await repo.save(sampleCycle());
    expect(saved.id).toMatch(/^cycle_/);
    expect(typeof saved.createdAt).toBe("string");
    expect(saved.itemReflections).toEqual([]);
    expect(saved.scoreReflection).toBeNull();
  });

  it("lists cycles oldest-first with distinct ids", async () => {
    const repo = new InMemoryCycleRepository();
    const a = await repo.save(sampleCycle());
    const b = await repo.save(sampleCycle());
    const all = await repo.list();
    expect(all).toHaveLength(2);
    expect(all[0].id).toBe(a.id);
    expect(all[1].id).toBe(b.id);
    expect(a.id).not.toBe(b.id);
  });

  it("attaches reflections to a stored cycle", async () => {
    const repo = new InMemoryCycleRepository();
    const saved = await repo.save(sampleCycle());
    const updated = await repo.attachReflections(saved.id, {
      itemReflections: [],
      scoreReflection: { answers: { gap: "moved fast" } },
    });
    expect(updated.scoreReflection?.answers.gap).toBe("moved fast");
    const [fromStore] = await repo.list();
    expect(fromStore.scoreReflection?.answers.gap).toBe("moved fast");
  });

  it("rejects attaching to an unknown id", async () => {
    const repo = new InMemoryCycleRepository();
    await expect(
      repo.attachReflections("missing", { itemReflections: [], scoreReflection: null }),
    ).rejects.toThrow(RangeError);
  });

  it("starts empty", async () => {
    const repo = new InMemoryCycleRepository();
    expect(await repo.list()).toHaveLength(0);
  });
});
