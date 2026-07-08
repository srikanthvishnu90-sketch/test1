import { describe, it, expect } from "vitest";
import { recordCycle, attachReflections } from "./recordCycle";
import { InMemoryCycleRepository } from "@/adapters/memory/inMemoryCycleRepository";
import { createReflection } from "@/domain/reflection";
import { createScoreReflection } from "@/domain/scoreReflection";

describe("recordCycle", () => {
  it("assembles, calibrates, and persists a cycle with empty reflections", async () => {
    const repo = new InMemoryCycleRepository();
    const cycle = await recordCycle(repo, {
      items: [
        { itemId: "q1", confidence: 1, correct: true },
        { itemId: "q2", confidence: 0, correct: false },
      ],
      predictedScore: 0.5,
    });

    expect(cycle.id).toMatch(/^cycle_/);
    expect(cycle.calibration.brier).toBeCloseTo(0, 10);
    expect(cycle.itemReflections).toEqual([]);
    expect(cycle.scoreReflection).toBeNull();
    expect(await repo.list()).toHaveLength(1);
  });

  it("propagates domain invariant violations as a rejection", async () => {
    const repo = new InMemoryCycleRepository();
    await expect(
      recordCycle(repo, { items: [], predictedScore: 0.5 }),
    ).rejects.toThrow();
    expect(await repo.list()).toHaveLength(0);
  });
});

describe("attachReflections", () => {
  it("attaches item + score reflections to a saved cycle", async () => {
    const repo = new InMemoryCycleRepository();
    const cycle = await recordCycle(repo, {
      items: [{ itemId: "q1", confidence: 0.9, correct: false }],
      predictedScore: 0.9,
    });

    const reflection = createReflection({
      causeId: "rushed",
      nextAction: "Slow down and re-read.",
    });
    const scoreReflection = createScoreReflection({ gap: "I moved too fast." });

    const updated = await attachReflections(repo, cycle.id, {
      itemReflections: [reflection],
      scoreReflection,
    });

    expect(updated.itemReflections).toHaveLength(1);
    expect(updated.scoreReflection?.answers.gap).toBe("I moved too fast.");

    const [fromStore] = await repo.list();
    expect(fromStore.itemReflections).toHaveLength(1);
    expect(fromStore.scoreReflection?.answers.gap).toBe("I moved too fast.");
  });

  it("rejects an unknown cycle id", async () => {
    const repo = new InMemoryCycleRepository();
    await expect(
      attachReflections(repo, "nope", { itemReflections: [], scoreReflection: null }),
    ).rejects.toThrow(RangeError);
  });
});
