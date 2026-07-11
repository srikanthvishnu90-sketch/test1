import { describe, it, expect } from "vitest";
import {
  createReflectionSession,
  studentsWantingExtraHelp,
  studentsWantingReview,
  studentsWantingTutor,
  type ReflectionSession,
} from "./session";

function session(
  studentId: string,
  flags: Partial<
    Pick<
      ReflectionSession,
      "extraHelpRequested" | "reviewRequested" | "tutorRequested"
    >
  > = {},
): ReflectionSession {
  return createReflectionSession({
    id: `lesson-1:${studentId}`,
    reflectionId: "lesson-1",
    studentId,
    status: "completed",
    messages: [],
    ...flags,
    startedAt: new Date("2026-01-01T00:00:00Z"),
    completedAt: new Date("2026-01-01T00:05:00Z"),
  });
}

describe("createReflectionSession", () => {
  it("round-trips the request flags", () => {
    const s = session("s-avery", {
      extraHelpRequested: true,
      reviewRequested: true,
      tutorRequested: false,
    });
    expect(s.extraHelpRequested).toBe(true);
    expect(s.reviewRequested).toBe(true);
    expect(s.tutorRequested).toBe(false);
    expect(session("s-casey").extraHelpRequested).toBeUndefined();
  });
});

describe("student request readers", () => {
  const sessions = [
    session("s-avery", { extraHelpRequested: true, tutorRequested: true }),
    session("s-blake", { reviewRequested: true }),
    session("s-casey", {}),
    session("s-avery", { extraHelpRequested: true }), // duplicate student
  ];

  it("each reader returns only its own askers, deduped, in first-seen order", () => {
    expect(studentsWantingExtraHelp(sessions)).toEqual(["s-avery"]);
    expect(studentsWantingTutor(sessions)).toEqual(["s-avery"]);
    expect(studentsWantingReview(sessions)).toEqual(["s-blake"]);
  });

  it("is empty when no one asked", () => {
    expect(studentsWantingTutor([session("s-avery"), session("s-blake")])).toEqual([]);
  });
});
