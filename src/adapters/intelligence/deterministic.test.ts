import { describe, it, expect } from "vitest";
import { createDeterministicReflectionIntelligence } from "@/adapters/intelligence";
import {
  createReflectionMessage,
  createReflectionSession,
  type ReflectionSession,
} from "@/domain/intelligence/session";
import {
  createGeneratedQuestion,
  createReflectionQuestionSet,
  type ReflectionQuestionSet,
} from "@/domain/intelligence/question";

const NOW = new Date("2026-07-12T00:00:00Z");
const intel = createDeterministicReflectionIntelligence({
  now: () => NOW,
  safetyCheck: () => false,
});

const PRIMARIES = [
  { text: "How clear did it feel?", format: "rating" as const, category: "technical" as const },
  { text: "Which word fits?", format: "emotion_select" as const, category: "emotional" as const, options: ["confident", "confused"] },
  { text: "What was hard?", format: "short_response" as const, category: "technical" as const },
  { text: "Next time?", format: "short_response" as const, category: "metacognitive" as const },
];

function questionSet(): ReflectionQuestionSet {
  return createReflectionQuestionSet({
    lessonId: "lesson-x",
    questions: PRIMARIES.map((q, i) =>
      createGeneratedQuestion({ id: `q${i}`, order: i, category: q.category, text: q.text, format: q.format, options: q.options, required: i < 2, aiGenerated: true }),
    ),
    adaptiveFollowupsEnabled: true,
    maxFollowups: 4,
    createdAt: NOW,
  });
}
const qs = questionSet();

/** A session where each answer follows its real primary question (no probes). */
function sessionOf(studentTexts: string[]): ReflectionSession {
  const messages = studentTexts.flatMap((t, i) => [
    createReflectionMessage({ id: `ai${i}`, sessionId: "s", sender: "ai", text: PRIMARIES[i].text, createdAt: NOW }),
    createReflectionMessage({ id: `st${i}`, sessionId: "s", sender: "student", text: t, createdAt: NOW }),
  ]);
  return createReflectionSession({ id: "s", reflectionId: "lesson-x", studentId: "stu", status: "active", startedAt: NOW, messages });
}
function appendAi(s: ReflectionSession, text: string): ReflectionSession {
  return createReflectionSession({ ...s, messages: [...s.messages, createReflectionMessage({ id: `ai-${s.messages.length}`, sessionId: "s", sender: "ai", text, createdAt: NOW })] });
}
function appendStudent(s: ReflectionSession, text: string): ReflectionSession {
  return createReflectionSession({ ...s, messages: [...s.messages, createReflectionMessage({ id: `st-${s.messages.length}`, sessionId: "s", sender: "student", text, createdAt: NOW })] });
}

describe("deterministic nextTurn — intent routing & follow-ups", () => {
  it("summarizes after a specific final answer (no needless follow-up)", async () => {
    const step = await intel.nextTurn({ session: sessionOf(["Mostly", "confident", "the middle term", "re-check each step"]), questionSet: qs });
    expect(step.kind).toBe("summary");
  });

  it("does NOT treat a short but specific answer as vague", async () => {
    const step = await intel.nextTurn({ session: sessionOf(["Mostly", "confident", "the middle term", "the signs"]), questionSet: qs });
    expect(step.kind).toBe("summary");
  });

  it("breaks the concept into pieces when the student says 'everything'", async () => {
    const step = await intel.nextTurn({ session: sessionOf(["Mostly", "confident", "the middle term", "everything"]), questionSet: qs });
    if (step.kind !== "question") throw new Error("expected breakdown");
    expect(step.format).toBe("multiple_choice");
    expect(step.options?.length).toBeGreaterThan(2);
    expect(step.text.toLowerCase()).toMatch(/hardest|shakiest|part/);
  });

  it("routes an off-topic answer to a question-anchored probe", async () => {
    const step = await intel.nextTurn({ session: sessionOf(["Mostly", "confident", "the middle term", "I love the blue sky, totally unrelated"]), questionSet: qs });
    if (step.kind !== "question") throw new Error("expected probe");
    expect(step.text.toLowerCase()).toMatch(/come back|bring it back|though/);
  });

  it("routes gibberish to a 'didn't catch that' probe", async () => {
    const step = await intel.nextTurn({ session: sessionOf(["Mostly", "confident", "the middle term", "asdfghjkl"]), questionSet: qs });
    if (step.kind !== "question") throw new Error("expected probe");
    expect(step.text.toLowerCase()).toContain("catch that");
  });

  it("honors a refusal with an out", async () => {
    const step = await intel.nextTurn({ session: sessionOf(["Mostly", "confident", "the middle term", "I'd rather not say"]), questionSet: qs });
    if (step.kind !== "question") throw new Error("expected probe");
    expect(step.text.toLowerCase()).toContain("skip");
  });

  it("advances to the next primary after a probe — never loops", async () => {
    // p0 answered off-topic, a probe was asked and answered → must move to p1.
    let session = sessionOf(["totally unrelated nvm"]);
    const probe = await intel.nextTurn({ session, questionSet: qs });
    if (probe.kind !== "question") throw new Error("expected probe");
    expect(probe.text.toLowerCase()).toMatch(/come back|bring it back|though/);
    session = appendStudent(appendAi(session, probe.text), "the middle term signs");
    const next = await intel.nextTurn({ session, questionSet: qs });
    if (next.kind !== "question") throw new Error("expected next primary");
    expect(next.text).toBe(PRIMARIES[1].text); // advanced, did not re-probe
  });

  it("never repeats the breakdown", async () => {
    let session = sessionOf(["Mostly", "confident", "the middle term", "all of it"]);
    const first = await intel.nextTurn({ session, questionSet: qs });
    if (first.kind !== "question") throw new Error("expected breakdown");
    session = appendStudent(appendAi(session, first.text), "getting started");
    const second = await intel.nextTurn({ session, questionSet: qs });
    expect(second.kind).toBe("summary");
  });
});
