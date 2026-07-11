import { type Id } from "../common";
import {
  reflectionMessageSchema,
  reflectionSessionSchema,
} from "../schemas/intelligence";
import type { QuestionCategory } from "./question";

/**
 * The adaptive student reflection — a short chatbot conversation, one question at
 * a time (spec → Student AI reflection chatbot). It walks the six stages
 * (overall → technical → emotional → behavioral → support → action) but stops
 * early once enough is known. The message log IS the record the summary is built
 * from; nothing else is stored about what the student "is".
 */

export type MessageSender = "student" | "ai";

export type ReflectionStage =
  | "overall"
  | "technical"
  | "emotional"
  | "behavioral"
  | "support"
  | "action";

export type SessionStatus = "active" | "completed" | "abandoned" | "escalated";

export interface ReflectionMessage {
  id: Id;
  sessionId: Id;
  sender: MessageSender;
  text: string;
  /** The reasoning category this turn belongs to (for signal extraction). */
  category?: QuestionCategory;
  createdAt: Date;
}

export interface ReflectionSession {
  id: Id;
  reflectionId: Id;
  studentId: Id;
  status: SessionStatus;
  messages: ReflectionMessage[];
  /** The one practical next step the student chose (Stage 6). */
  selectedAction?: string;
  /** Whether the student confirmed (vs corrected) the AI's summary. */
  studentConfirmedSummary?: boolean;
  /** The student asked to set up time outside class with their teacher. */
  extraHelpRequested?: boolean;
  /** The student asked that this topic get more time on a review day. */
  reviewRequested?: boolean;
  /** The student asked to set up time with a tutor. */
  tutorRequested?: boolean;
  startedAt: Date;
  completedAt?: Date;
}

/** The six stages, in order — the spine of the conversation. */
export const REFLECTION_STAGES: readonly ReflectionStage[] = [
  "overall",
  "technical",
  "emotional",
  "behavioral",
  "support",
  "action",
];

export function createReflectionMessage(input: ReflectionMessage): ReflectionMessage {
  return Object.freeze(reflectionMessageSchema.parse(input));
}

export function createReflectionSession(input: ReflectionSession): ReflectionSession {
  return Object.freeze(reflectionSessionSchema.parse(input));
}

/** The student answers so far, oldest → newest. */
export function studentAnswers(session: ReflectionSession): ReflectionMessage[] {
  return session.messages.filter((m) => m.sender === "student");
}

/**
 * The distinct students, in first-seen order, whose sessions match a predicate.
 * The building block for the student-initiated requests below — each is RECORDED
 * from what the student chose, never inferred, so the teacher acts on a real ask.
 */
function distinctStudents(
  sessions: readonly ReflectionSession[],
  matches: (session: ReflectionSession) => boolean,
): Id[] {
  const seen = new Set<Id>();
  const out: Id[] = [];
  for (const session of sessions) {
    if (matches(session) && !seen.has(session.studentId)) {
      seen.add(session.studentId);
      out.push(session.studentId);
    }
  }
  return out;
}

/** Students who asked to set up time outside class with their teacher. */
export function studentsWantingExtraHelp(sessions: readonly ReflectionSession[]): Id[] {
  return distinctStudents(sessions, (s) => s.extraHelpRequested === true);
}

/** Students who asked that this topic get more time on a review day. */
export function studentsWantingReview(sessions: readonly ReflectionSession[]): Id[] {
  return distinctStudents(sessions, (s) => s.reviewRequested === true);
}

/** Students who asked to set up time with a tutor. */
export function studentsWantingTutor(sessions: readonly ReflectionSession[]): Id[] {
  return distinctStudents(sessions, (s) => s.tutorRequested === true);
}
