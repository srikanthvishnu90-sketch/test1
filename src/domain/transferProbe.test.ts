import { describe, it, expect } from "vitest";
import { scoreProbe, type TransferProbe } from "./transferProbe";

const probe: TransferProbe = {
  id: "p1",
  statement: "A pentagon has five sides.",
  isTrue: true,
};

describe("scoreProbe", () => {
  it("marks a correct answer as transferred", () => {
    expect(scoreProbe(probe, true).transferred).toBe(true);
  });

  it("marks a wrong answer as not transferred (fluency illusion)", () => {
    expect(scoreProbe(probe, false).transferred).toBe(false);
  });
});
