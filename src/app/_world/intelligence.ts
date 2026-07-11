import { createLesson } from "@/domain/intelligence/lesson";
import {
  createReflectionMessage,
  createReflectionSession,
} from "@/domain/intelligence/session";
import {
  createDeterministicReflectionIntelligence,
  createLlmReflectionIntelligence,
} from "@/adapters/intelligence";
import { PINNED_MODELS, createHttpGateway } from "@/adapters/language";
import {
  createMemoryClassSummaryRepository,
  createMemoryLessonRepository,
  createMemoryPerformanceRepository,
  createMemoryQuestionSetRepository,
  createMemoryReflectionSessionRepository,
  createMemoryStudentSummaryRepository,
} from "@/adapters/memory/intelligenceRepositories";
import type { ReflectionIntelligence } from "@/domain/ports/intelligence";
import type {
  ClassSummaryRepository,
  LessonRepository,
  PerformanceRepository,
  QuestionSetRepository,
  ReflectionSessionRepository,
  StudentSummaryRepository,
} from "@/domain/ports/intelligenceRepositories";

/**
 * Wires the reflection-intelligence service and its repositories into the world.
 * The deterministic adapter is the default — and it carries the crisis-safety
 * check (injected from the sanctioned safety boundary, boolean-only) as its safety
 * hook, so the adaptive chat yields to a safety concern even with zero key. When
 * ANTHROPIC_API_KEY is set, the LLM adapter fronts it for drafting; the
 * deterministic adapter (with safety) stays the fallback, so safety and flow are
 * never at the model's mercy.
 */

export interface IntelRepos {
  lessons: LessonRepository;
  questionSets: QuestionSetRepository;
  sessions: ReflectionSessionRepository;
  studentSummaries: StudentSummaryRepository;
  classSummaries: ClassSummaryRepository;
  performances: PerformanceRepository;
}

export function buildIntelligence(
  now: () => Date,
  safetyCheck: (text: string) => boolean,
): ReflectionIntelligence {
  const deterministic = createDeterministicReflectionIntelligence({ now, safetyCheck });
  const apiKey = process.env.ANTHROPIC_API_KEY;
  if (apiKey === undefined || apiKey.length === 0) return deterministic;
  const gateway = createHttpGateway({
    apiKey,
    models: PINNED_MODELS,
    now,
    timeoutMs: 8000,
  });
  return createLlmReflectionIntelligence({ gateway, fallback: deterministic, now });
}

export function buildIntelRepos(): IntelRepos {
  return {
    lessons: createMemoryLessonRepository(),
    questionSets: createMemoryQuestionSetRepository(),
    sessions: createMemoryReflectionSessionRepository(),
    studentSummaries: createMemoryStudentSummaryRepository(),
    classSummaries: createMemoryClassSummaryRepository(),
    performances: createMemoryPerformanceRepository(),
  };
}

/** The seeded demo lesson every student can reflect on (id == reflectionId). */
export const DEMO_REFLECTION_ID = "lesson-demo";

/** Seed one lesson + its AI-generated question set so the chat runs out of the box. */
export async function seedDemoReflection(
  intelligence: ReflectionIntelligence,
  intel: IntelRepos,
  now: () => Date,
): Promise<void> {
  const lesson = createLesson({
    id: DEMO_REFLECTION_ID,
    classId: "class-1",
    teacherId: "teacher-1",
    title: "Factoring quadratic equations",
    date: now(),
    lessonType: "independent_practice",
    content:
      "I modeled three examples of factoring quadratic equations, then students solved six problems independently.",
    objectives: [],
    standards: [],
    createdAt: now(),
  });
  await intel.lessons.save(lesson);
  const analysis = await intelligence.analyzeLesson({ lesson });
  const set = await intelligence.generateReflectionQuestions({
    analysis,
    depth: "standard",
    adaptiveFollowups: true,
  });
  await intel.questionSets.save(set);

  // Seed a small, believable class on the demo lesson so the teacher's reflection
  // tab shows real progress counts and a struggling-concept flag out of the box:
  // two students finished (both stuck on factoring), one is still working on it.
  // Avery finished, is stuck on factoring, and asked for teacher time + a tutor.
  await seedCompletedReflection(intelligence, intel, DEMO_REFLECTION_ID, "student-avery", [
    "It was pretty confusing — I didn't really get the factoring part.",
    "I wasn't sure which method to use to start.",
  ], now, { extraHelp: true, tutor: true });
  // Blake is stuck on factoring, mentions something outside class, wants a review day.
  await seedCompletedReflection(intelligence, intel, DEMO_REFLECTION_ID, "student-blake", [
    "I got lost on factoring the quadratic problems we did.",
    "Honestly I was up all night helping out at home, so I was pretty tired and couldn't focus.",
  ], now, { review: true });
  await seedActiveReflection(intel, DEMO_REFLECTION_ID, "student-casey", now);
}

/** Build the alternating AI/student message log a seeded reflection needs. */
function seedMessages(
  sessionId: string,
  answers: string[],
  now: () => Date,
): ReturnType<typeof createReflectionMessage>[] {
  const messages: ReturnType<typeof createReflectionMessage>[] = [];
  let i = 0;
  const add = (sender: "ai" | "student", text: string): void => {
    messages.push(
      createReflectionMessage({
        id: `${sessionId}-m${i++}`,
        sessionId,
        sender,
        text,
        category: sender === "ai" ? "technical" : undefined,
        createdAt: now(),
      }),
    );
  };
  for (const answer of answers) {
    add("ai", "How did that part of today's work go?");
    add("student", answer);
  }
  return messages;
}

/**
 * Seed one finished reflection: record the conversation, then run the same
 * signal-extraction + summary the live chat runs on completion, so the class brief
 * and the struggling-concept read both see it. Resilient: if summarizing throws,
 * the completed session is still saved (counts stay correct).
 */
async function seedCompletedReflection(
  intelligence: ReflectionIntelligence,
  intel: IntelRepos,
  reflectionId: string,
  studentId: string,
  answers: string[],
  now: () => Date,
  options: { extraHelp?: boolean; review?: boolean; tutor?: boolean } = {},
): Promise<void> {
  // A distinct id namespace so a student running the demo survey live (which uses
  // `${reflectionId}:${studentId}`) never clobbers this seeded teacher-demo data.
  const sessionId = `seed:${reflectionId}:${studentId}`;
  const session = createReflectionSession({
    id: sessionId,
    reflectionId,
    studentId,
    status: "active",
    startedAt: now(),
    messages: seedMessages(sessionId, answers, now),
  });
  await intel.sessions.save(
    createReflectionSession({
      ...session,
      status: "completed",
      completedAt: now(),
      extraHelpRequested: options.extraHelp === true ? true : undefined,
      reviewRequested: options.review === true ? true : undefined,
      tutorRequested: options.tutor === true ? true : undefined,
    }),
  );
  try {
    const signals = await intelligence.extractSignals({ session });
    const summary = await intelligence.summarizeStudentReflection({ session, signals });
    await intel.studentSummaries.save(summary);
  } catch {
    // The brief simply won't include this student; progress + concepts are unaffected.
  }
}

/** Seed one reflection a student has opened but not finished ("working on it"). */
async function seedActiveReflection(
  intel: IntelRepos,
  reflectionId: string,
  studentId: string,
  now: () => Date,
): Promise<void> {
  const sessionId = `seed:${reflectionId}:${studentId}`;
  await intel.sessions.save(
    createReflectionSession({
      id: sessionId,
      reflectionId,
      studentId,
      status: "active",
      startedAt: now(),
      messages: seedMessages(sessionId, [], now).concat(
        createReflectionMessage({
          id: `${sessionId}-m0`,
          sessionId,
          sender: "ai",
          text: "How did today's work feel overall?",
          category: "technical",
          createdAt: now(),
        }),
      ),
    }),
  );
}
