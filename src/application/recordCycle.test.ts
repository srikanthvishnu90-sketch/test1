import { describe, it, expect } from "vitest";
import { recordCycle } from "./recordCycle";
import { InMemoryCycleRepository } from "@/adapters/memory/inMemoryCycleRepository";

describe("recordCycle", () => {
  it("assembles, calibrates, and persists a cycle", async () => {
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
    expect(cycle.reflection).toBeNull();
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
