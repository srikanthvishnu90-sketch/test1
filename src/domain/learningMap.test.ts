import { describe, it, expect } from "vitest";
import { locateOnMap } from "./learningMap";

describe("locateOnMap", () => {
  it("starts at the first stage with no evidence", () => {
    expect(locateOnMap([]).id).toBe("forming");
  });

  it("locates a well-calibrated student as reliable", () => {
    expect(locateOnMap([0.05, 0.08]).id).toBe("reliable");
  });

  it("locates a middling student as emerging", () => {
    expect(locateOnMap([0.2, 0.2]).id).toBe("emerging");
  });

  it("locates a poorly-calibrated student as forming", () => {
    expect(locateOnMap([0.4, 0.5]).id).toBe("forming");
  });

  it("uses the mean across recent cycles, not a single judgment", () => {
    // one great, one poor → mean 0.25 → emerging, not reliable
    expect(locateOnMap([0.0, 0.5]).id).toBe("emerging");
  });
});
