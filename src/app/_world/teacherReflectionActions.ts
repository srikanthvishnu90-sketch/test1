"use server";

import {
  createLesson,
  type LessonAnalysis,
  type LessonType,
} from "@/domain/intelligence/lesson";
import type {
  ClassInsightSummary,
  StudentInsightSummary,
} from "@/domain/intelligence/insight";
import { createReflectionPerformance } from "@/domain/intelligence/metacognition";
import {
  studentAnswers,
  studentsWantingExtraHelp,
  studentsWantingReview,
  studentsWantingTutor,
} from "@/domain/intelligence/session";
import {
  identifyStrugglingConcepts,
  hasStruggleSignal,
  type ReflectionStruggleInput,
} from "@/domain/intelligence/strugglingConcepts";
import {
  detectExternalFactors,
  externalFactorLabels,
  type ExternalFactorCategory,
} from "@/domain/intelligence/externalFactors";
import type {
  ClassStudentInput,
  ReflectionDepth,
} from "@/domain/ports/intelligence";
import { getSessionUser } from "./session";
import { getWorld } from "./world";
import { TEACHER_ID, studentDisplayName } from "./teacher";
import { COUNSELOR_NAME } from "./roles";
import { getLessonPhotos, saveLessonPhotos } from "./lessonMedia";

/**
 * The teacher side of the reflection loop: enter a lesson, and the AI reads it,
 * drafts a short balanced reflection, and (once students have reflected) rolls
 * their summaries into one class brief with attention groups and a plan. The AI
 * only drafts and structures here — counts and grouping are deterministic, and
 * no diagnosis can pass the summary factories.
 */

/** The demo teacher owns one class; a real build resolves this from the roster. */
const TEACHER_CLASS_ID = "class-1";

export interface NewLessonInput {
  title: string;
  lessonType: LessonType;
  content: string;
  /** Optional photos of the day's work, as data URLs. */
  photos?: string[];
}

export interface LessonDetail {
  reflectionId: string;
  title: string;
  lessonType: LessonType;
  content: string;
  photos: string[];
}

export interface LessonListItem {
  reflectionId: string;
  title: string;
  lessonType: LessonType;
  reflectionCount: number;
  completedCount: number;
  hasBrief: boolean;
}

export interface ClassBriefView {
  brief: ClassInsightSummary;
  students: StudentInsightSummary[];
}

export interface StudentScoreRow {
  studentId: string;
  name: string;
  /** The score already recorded for this reflection, as a percent, or null. */
  scorePercent: number | null;
}

async function requireTeacher(): Promise<void> {
  const user = await getSessionUser();
  if (user === null || user.role !== "teacher") {
    throw new Error("Only a teacher can do this.");
  }
}

function slug(title: string): string {
  return title
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);
}

/** Every lesson the teacher's class has, newest activity first, with reflection tallies. */
export async function listTeacherLessons(): Promise<LessonListItem[]> {
  await requireTeacher();
  const world = await getWorld();
  const lessons = await world.intel.lessons.listByClass(TEACHER_CLASS_ID);
  const items = await Promise.all(
    lessons.map(async (lesson): Promise<LessonListItem> => {
      const sessions = await world.intel.sessions.listByReflection(lesson.id);
      const brief = await world.intel.classSummaries.findByReflection(lesson.id);
      return {
        reflectionId: lesson.id,
        title: lesson.title,
        lessonType: lesson.lessonType,
        reflectionCount: sessions.length,
        completedCount: sessions.filter((s) => s.status === "completed").length,
        hasBrief: brief !== null,
      };
    }),
  );
  return items;
}

/**
 * Create a lesson, let the AI read it and draft the reflection, and persist both.
 * Returns the reflectionId (== lesson id) the student chat and brief hang off.
 */
export async function createLessonReflection(input: NewLessonInput): Promise<string> {
  await requireTeacher();
  const world = await getWorld();
  const now = world.clock.now();
  const title = input.title.trim();
  if (title.length === 0) throw new Error("A lesson needs a title.");
  if (input.content.trim().length === 0) {
    throw new Error("Add a few lines about what happened in class.");
  }
  const id = `lesson-${slug(title)}-${now.getTime()}`;
  const lesson = createLesson({
    id,
    classId: TEACHER_CLASS_ID,
    teacherId: TEACHER_ID,
    title,
    date: now,
    lessonType: input.lessonType,
    content: input.content.trim(),
    objectives: [],
    standards: [],
    createdAt: now,
  });
  await world.intel.lessons.save(lesson);
  if (input.photos !== undefined && input.photos.length > 0) {
    saveLessonPhotos(id, input.photos);
  }
  const analysis = await world.intelligence.analyzeLesson({ lesson });
  const set = await world.intelligence.generateReflectionQuestions({
    analysis,
    depth: "standard",
    adaptiveFollowups: true,
  });
  await world.intel.questionSets.save(set);
  return id;
}

export interface SurveyPreviewQuestion {
  category: string;
  format: string;
  text: string;
  options?: string[];
}

export interface SurveyPreview {
  questions: SurveyPreviewQuestion[];
  adaptiveFollowups: boolean;
  maxFollowups: number;
}

/**
 * Generate the reflection survey a lesson WOULD get — without creating anything.
 * Lets a teacher type a lesson and see the exact questions students would be asked,
 * at any depth, before committing. Reads through the same analyze → generate path
 * as the real thing, but saves nothing (no lesson, no question set, no session).
 */
export async function previewReflectionSurvey(input: {
  title: string;
  lessonType: LessonType;
  content?: string;
  depth?: ReflectionDepth;
}): Promise<SurveyPreview> {
  await requireTeacher();
  const world = await getWorld();
  const now = world.clock.now();
  const title = input.title.trim();
  if (title.length === 0) {
    throw new Error("Add a lesson title to preview the survey.");
  }
  // Content sharpens the draft, but a title alone is enough to preview.
  const content = (input.content ?? "").trim() || title;
  const lesson = createLesson({
    id: `preview-${slug(title)}`,
    classId: TEACHER_CLASS_ID,
    teacherId: TEACHER_ID,
    title,
    date: now,
    lessonType: input.lessonType,
    content,
    objectives: [],
    standards: [],
    createdAt: now,
  });
  const analysis = await world.intelligence.analyzeLesson({ lesson });
  const set = await world.intelligence.generateReflectionQuestions({
    analysis,
    depth: input.depth ?? "standard",
    adaptiveFollowups: true,
  });
  return {
    questions: set.questions.map((q) => ({
      category: q.category,
      format: q.format,
      text: q.text,
      options: q.options,
    })),
    adaptiveFollowups: set.adaptiveFollowupsEnabled,
    maxFollowups: set.maxFollowups,
  };
}

/** The lesson's own content — the summary of the day and any photos the teacher added. */
export async function getLessonDetail(reflectionId: string): Promise<LessonDetail | null> {
  await requireTeacher();
  const world = await getWorld();
  const lesson = await world.intel.lessons.findById(reflectionId);
  if (lesson === null) return null;
  return {
    reflectionId,
    title: lesson.title,
    lessonType: lesson.lessonType,
    content: lesson.content,
    photos: getLessonPhotos(reflectionId),
  };
}

/**
 * Roll every completed reflection for a lesson into one class brief. Re-derives
 * each student's signals deterministically, aggregates via the intelligence
 * service, persists the brief, and returns it with the per-student summaries.
 * Returns null until at least one student has finished reflecting.
 */
export async function buildClassBrief(reflectionId: string): Promise<ClassBriefView | null> {
  await requireTeacher();
  const world = await getWorld();
  const sessions = (await world.intel.sessions.listByReflection(reflectionId)).filter(
    (s) => s.status === "completed",
  );
  const students: ClassStudentInput[] = [];
  const summaries: StudentInsightSummary[] = [];
  const seen = new Set<string>();
  for (const session of sessions) {
    if (seen.has(session.studentId)) continue; // one reflection per student
    seen.add(session.studentId);
    const summary = await world.intel.studentSummaries.findByReflectionAndStudent(
      reflectionId,
      session.studentId,
    );
    if (summary === null) continue;
    const signals = await world.intelligence.extractSignals({ session });
    students.push({ studentId: session.studentId, summary, signals });
    summaries.push(summary);
  }
  if (students.length === 0) return null;
  const brief = await world.intelligence.summarizeClassReflection({
    classId: TEACHER_CLASS_ID,
    reflectionId,
    students,
  });
  await world.intel.classSummaries.save(brief);
  return { brief, students: summaries };
}

/**
 * The students who finished reflecting on a lesson, with any score already recorded
 * — the roster the teacher enters graded results against (P7 score entry).
 */
export async function listScoreRows(reflectionId: string): Promise<StudentScoreRow[]> {
  await requireTeacher();
  const world = await getWorld();
  const sessions = (await world.intel.sessions.listByReflection(reflectionId)).filter(
    (s) => s.status === "completed",
  );
  const seen = new Set<string>();
  const rows: StudentScoreRow[] = [];
  for (const session of sessions) {
    if (seen.has(session.studentId)) continue;
    seen.add(session.studentId);
    const perf = await world.intel.performances.findByReflectionAndStudent(
      reflectionId,
      session.studentId,
    );
    rows.push({
      studentId: session.studentId,
      name: studentDisplayName(session.studentId),
      scorePercent: perf === null ? null : Math.round(perf.score * 100),
    });
  }
  return rows;
}

/**
 * Record a graded result (0–100%) for one student's reflection. This is the honest
 * score the reflection's self-confidence is later set beside — never a pre-registered
 * bet. Overwrites any prior score for the same (reflection, student).
 */
export async function recordReflectionScore(
  reflectionId: string,
  studentId: string,
  scorePercent: number,
): Promise<void> {
  await requireTeacher();
  if (!Number.isFinite(scorePercent) || scorePercent < 0 || scorePercent > 100) {
    throw new Error("A score must be between 0 and 100.");
  }
  const world = await getWorld();
  await world.intel.performances.save(
    createReflectionPerformance({
      reflectionId,
      studentId,
      score: scorePercent / 100,
      recordedAt: world.clock.now(),
    }),
  );
}

export interface ReflectionProgress {
  rosterCount: number;
  completed: number;
  inProgress: number;
  notStarted: number;
}

/**
 * Where the class is on a reflection: how many students have finished, how many
 * are mid-conversation, and how many haven't opened it. Deterministic counting
 * over the class roster and session statuses — each student is counted once, and
 * having finished outranks an in-progress retry.
 */
export async function getReflectionProgress(
  reflectionId: string,
): Promise<ReflectionProgress> {
  await requireTeacher();
  const world = await getWorld();
  const roster = world.students.map((s) => s.id);
  const sessions = await world.intel.sessions.listByReflection(reflectionId);
  const completed = new Set<string>();
  const active = new Set<string>();
  for (const session of sessions) {
    if (session.status === "completed") completed.add(session.studentId);
    else if (session.status === "active") active.add(session.studentId);
  }
  for (const id of completed) active.delete(id); // finished outranks in-progress
  const started = new Set<string>([...completed, ...active]);
  const notStarted = roster.filter((id) => !started.has(id)).length;
  return {
    rosterCount: roster.length,
    completed: completed.size,
    inProgress: active.size,
    notStarted,
  };
}

export interface StrugglingConceptView {
  concept: string;
  studentCount: number;
  studentNames: string[];
}

export interface StrugglingConceptsView {
  completedCount: number;
  concepts: StrugglingConceptView[];
}

/** Generic pedagogy words that are never the concept a class is "stuck on". */
const CONCEPT_STOPWORDS = new Set<string>([
  "students", "student", "example", "examples", "modeled", "problem", "problems",
  "independently", "independent", "practice", "lesson", "classroom", "homework",
  "worked", "working", "solved", "answer", "answers", "question", "questions",
  "today", "yesterday", "everyone", "something", "anything",
]);

/** Candidate concepts for a lesson, richest first, cleaned of generic words. */
function buildConceptPool(analysis: LessonAnalysis): string[] {
  const raw = [
    ...analysis.subtopics,
    ...analysis.misconceptions,
    ...analysis.technicalSteps,
    ...analysis.prerequisites,
    ...analysis.vocabulary,
  ];
  const out: string[] = [];
  const seen = new Set<string>();
  for (const term of raw) {
    const label = term.trim();
    const key = label.toLowerCase();
    if (label.length < 4 || CONCEPT_STOPWORDS.has(key) || seen.has(key)) continue;
    seen.add(key);
    out.push(label);
  }
  return out;
}

/**
 * Read across every finished reflection and flag the concept(s) a lot of students
 * are struggling with — surfaced to the teacher on the same reflection tab. The
 * signal extraction and concept pool are AI/analysis labor; the flagging itself is
 * deterministic (domain/intelligence/strugglingConcepts) and evidence-backed: each
 * flag names the students who both struggled AND mentioned the concept, never a
 * diagnosis. Returns null until a student finishes and something clears the bar.
 */
export async function getStrugglingConcepts(
  reflectionId: string,
): Promise<StrugglingConceptsView | null> {
  await requireTeacher();
  const world = await getWorld();
  const lesson = await world.intel.lessons.findById(reflectionId);
  if (lesson === null) return null;
  const sessions = (await world.intel.sessions.listByReflection(reflectionId)).filter(
    (s) => s.status === "completed",
  );
  if (sessions.length === 0) return null;

  const analysis = await world.intelligence.analyzeLesson({ lesson });
  const pool = buildConceptPool(analysis);

  const reflections: ReflectionStruggleInput[] = [];
  const seen = new Set<string>();
  for (const session of sessions) {
    if (seen.has(session.studentId)) continue;
    seen.add(session.studentId);
    const signals = await world.intelligence.extractSignals({ session, analysis });
    reflections.push({
      studentId: session.studentId,
      struggling: hasStruggleSignal(signals.technical),
      answerText: studentAnswers(session)
        .map((m) => m.text)
        .join(" \n "),
    });
  }

  const report = identifyStrugglingConcepts(pool, reflections);
  if (report.concepts.length === 0) return null;
  return {
    completedCount: report.completedCount,
    concepts: report.concepts.map((c) => ({
      concept: c.concept,
      studentCount: c.studentCount,
      studentNames: c.studentIds.map(studentDisplayName),
    })),
  };
}

export interface HelpRequest {
  studentId: string;
  name: string;
}

/**
 * The students who asked to set up time outside class for extra help on this
 * reflection. A plain read of the request each student made — the teacher's cue
 * to reach out, in the student's own initiative.
 */
export async function listHelpRequests(reflectionId: string): Promise<HelpRequest[]> {
  await requireTeacher();
  const world = await getWorld();
  const sessions = await world.intel.sessions.listByReflection(reflectionId);
  return studentsWantingExtraHelp(sessions).map((studentId) => ({
    studentId,
    name: studentDisplayName(studentId),
  }));
}

/** Students who asked that this topic get more time on a review day. */
export async function listReviewRequests(reflectionId: string): Promise<HelpRequest[]> {
  await requireTeacher();
  const world = await getWorld();
  const sessions = await world.intel.sessions.listByReflection(reflectionId);
  return studentsWantingReview(sessions).map((studentId) => ({
    studentId,
    name: studentDisplayName(studentId),
  }));
}

/** Students who asked to set up time with a tutor. */
export async function listTutorRequests(reflectionId: string): Promise<HelpRequest[]> {
  await requireTeacher();
  const world = await getWorld();
  const sessions = await world.intel.sessions.listByReflection(reflectionId);
  return studentsWantingTutor(sessions).map((studentId) => ({
    studentId,
    name: studentDisplayName(studentId),
  }));
}

export interface ExternalFactorFlag {
  studentId: string;
  name: string;
  /** Gentle, non-diagnostic phrases for what surfaced (e.g. "not sleeping enough"). */
  factors: string[];
  /** The student's own words that surfaced it — so the teacher can respond well. */
  excerpt: string;
}

export interface ExternalFactorFlags {
  /** The counselor to loop in when it seems beyond a classroom conversation. */
  counselorName: string;
  students: ExternalFactorFlag[];
}

function truncate(text: string, max: number): string {
  const t = text.trim();
  return t.length <= max ? t : `${t.slice(0, max - 1).trimEnd()}…`;
}

/**
 * Flag students whose own words point to something OUTSIDE school making school
 * harder — home, work, sleep, caregiving, loss, being over-committed — so the
 * teacher can check in gently or loop in the counselor. This is deterministic
 * routing over the student's words (never the model, never a diagnosis), and it
 * deliberately steps aside from any session already on the crisis path
 * (`escalated`), which the counselor owns. Returns null when nothing surfaced.
 */
export async function getExternalFactorFlags(
  reflectionId: string,
): Promise<ExternalFactorFlags | null> {
  await requireTeacher();
  const world = await getWorld();
  const sessions = await world.intel.sessions.listByReflection(reflectionId);
  const byStudent = new Map<
    string,
    { categories: Set<ExternalFactorCategory>; excerpt: string }
  >();
  for (const session of sessions) {
    if (session.status === "escalated") continue; // crisis path owns this student
    for (const message of studentAnswers(session)) {
      const hit = detectExternalFactors(message.text);
      if (hit === null) continue;
      const entry = byStudent.get(session.studentId) ?? {
        categories: new Set<ExternalFactorCategory>(),
        excerpt: message.text, // keep the FIRST triggering line as evidence
      };
      for (const category of hit.categories) entry.categories.add(category);
      byStudent.set(session.studentId, entry);
    }
  }
  if (byStudent.size === 0) return null;
  const students: ExternalFactorFlag[] = [];
  for (const [studentId, { categories, excerpt }] of byStudent) {
    students.push({
      studentId,
      name: studentDisplayName(studentId),
      factors: externalFactorLabels([...categories]),
      excerpt: truncate(excerpt, 180),
    });
  }
  return { counselorName: COUNSELOR_NAME, students };
}
