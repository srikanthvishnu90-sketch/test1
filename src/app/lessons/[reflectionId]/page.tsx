import Link from "next/link";
import { notFound, redirect } from "next/navigation";
import type { ReactElement } from "react";
import { getSessionUser } from "@/app/_world/session";
import {
  buildClassBrief,
  getLessonDetail,
  getExternalFactorFlags,
  getReflectionProgress,
  getStrugglingConcepts,
  listHelpRequests,
  listReviewRequests,
  listTutorRequests,
  listScoreRows,
  type ExternalFactorFlags,
  type HelpRequest,
  type ReflectionProgress,
  type StrugglingConceptsView,
} from "@/app/_world/teacherReflectionActions";
import { studentDisplayName } from "@/app/_world/teacher";
import type { AttentionGroup } from "@/domain/intelligence/insight";
import type { LessonType } from "@/domain/intelligence/lesson";
import ScoreEntry from "./ScoreEntry";

const LESSON_TYPE_LABELS: Record<LessonType, string> = {
  direct_instruction: "Direct instruction",
  discussion: "Discussion",
  group_work: "Group work",
  independent_practice: "Independent practice",
  lab: "Lab",
  presentation: "Presentation",
  project: "Project",
  review: "Review",
  assessment_prep: "Assessment prep",
  other: "Lesson",
};

/**
 * The class brief for one reflection: what the class understood, how it felt, what
 * it did, the one relationship between those, and a short plan. Attention groups
 * name WHO to check on and WHY, in observed language — never a diagnosis, never a
 * ranking. Alignment reads in ink; a group needing attention carries the warm
 * accent, never red.
 */

const GROUP_LABELS: Record<AttentionGroup, string> = {
  low_understanding_low_confidence: "Struggling and knows it",
  high_understanding_low_confidence: "Doing well but doubts it",
  low_understanding_high_confidence: "Confident past the evidence",
  significant_emotional_change: "A notable shift in how it felt",
  reflection_assessment_mismatch: "Reflection and work don't line up",
  repeated_help_avoidance: "Held back from asking for help",
  positive_improvement: "Clear step forward",
};

/** Groups that are good news read in ink; the rest carry the warm attention accent. */
const POSITIVE_GROUPS: ReadonlySet<AttentionGroup> = new Set<AttentionGroup>([
  "positive_improvement",
  "high_understanding_low_confidence",
]);

export default async function ClassBriefPage({
  params,
}: {
  params: Promise<{ reflectionId: string }>;
}): Promise<ReactElement> {
  const { reflectionId } = await params;
  const user = await getSessionUser();
  if (user === null || user.role !== "teacher") redirect("/signin");

  const lesson = await getLessonDetail(reflectionId);
  if (lesson === null) notFound();

  const progress = await getReflectionProgress(reflectionId);
  const struggling = await getStrugglingConcepts(reflectionId);
  const helpRequests = await listHelpRequests(reflectionId);
  const tutorRequests = await listTutorRequests(reflectionId);
  const reviewRequests = await listReviewRequests(reflectionId);
  const externalFactors = await getExternalFactorFlags(reflectionId);
  const view = await buildClassBrief(reflectionId);
  const scoreRows = await listScoreRows(reflectionId);
  const byGroup = new Map<AttentionGroup, string[]>();
  if (view !== null) {
    for (const s of view.brief.attentionStudents) {
      const names = byGroup.get(s.group) ?? [];
      names.push(studentDisplayName(s.studentId));
      byGroup.set(s.group, names);
    }
  }

  return (
    <main className="mx-auto w-full max-w-2xl px-6 py-14">
      <BackLink />

      {/* Today's lesson — the summary the teacher wrote, and any photos. */}
      <p className="mt-6 text-[12px] font-medium uppercase tracking-[0.2em] text-secondary">
        {LESSON_TYPE_LABELS[lesson.lessonType]}
      </p>
      <h1 className="mt-2 text-3xl font-medium tracking-tight text-ink-black">
        {lesson.title}
      </h1>
      <p className="mt-3 whitespace-pre-line text-[15px] leading-relaxed text-ink-black">
        {lesson.content}
      </p>
      {lesson.photos.length > 0 && (
        <div className="mt-4 grid grid-cols-3 gap-2 sm:grid-cols-4">
          {lesson.photos.map((src, i) => (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              key={i}
              src={src}
              alt={`Lesson photo ${i + 1}`}
              className="aspect-square w-full rounded-control border border-ink-wash object-cover"
            />
          ))}
        </div>
      )}

      <ProgressStrip progress={progress} />

      {helpRequests.length > 0 && (
        <RequestList
          label="Asked for time outside class"
          note={`${
            helpRequests.length === 1 ? "This student" : "These students"
          } said they'd like to set up time with you — a good moment to reach out.`}
          requests={helpRequests}
        />
      )}

      {tutorRequests.length > 0 && (
        <RequestList
          label="Would like a tutor"
          note={`${
            tutorRequests.length === 1 ? "This student" : "These students"
          } asked to set up time with a tutor — you can help connect them.`}
          requests={tutorRequests}
        />
      )}

      {externalFactors !== null && <ExternalFactors flags={externalFactors} />}

      {struggling !== null && <StrugglingConcepts view={struggling} />}

      {reviewRequests.length > 0 && (
        <RequestList
          label="Asked to revisit this on a review day"
          note={`${
            reviewRequests.length === 1 ? "This student" : "These students"
          } asked for more time on this topic on a review day.`}
          requests={reviewRequests}
        />
      )}

      {view === null ? (
        <p className="mt-10 rounded-card border border-ink-wash bg-white p-5 text-[15px] leading-relaxed text-secondary">
          The class brief appears once at least one student has finished reflecting on
          this lesson. You can still enter graded results below.
        </p>
      ) : (
        <ClassBriefBody view={view} byGroup={byGroup} />
      )}

      <section className="mt-10">
        <h2 className="text-[13px] font-medium uppercase tracking-[0.16em] text-secondary">
          Graded results
        </h2>
        <p className="mt-2 text-[14px] text-secondary">
          Enter each student&rsquo;s score for this work. It sits beside how sure they
          felt on their own timeline — recorded after the fact, never a bet up front.
        </p>
        <div className="mt-4">
          <ScoreEntry reflectionId={reflectionId} rows={scoreRows} />
        </div>
      </section>
    </main>
  );
}

function ClassBriefBody({
  view,
  byGroup,
}: {
  view: NonNullable<Awaited<ReturnType<typeof buildClassBrief>>>;
  byGroup: Map<AttentionGroup, string[]>;
}): ReactElement {
  const { brief, students } = view;
  return (
    <>
      <p className="mt-10 text-[12px] font-medium uppercase tracking-[0.2em] text-secondary">
        Class brief · {students.length} reflection{students.length === 1 ? "" : "s"}
      </p>
      <h2 className="mt-2 text-2xl font-medium tracking-tight text-ink-black">
        Where the class landed
      </h2>

      <div className="mt-8 flex flex-col gap-4">
        <Panel label="Understanding">{brief.technicalSummary}</Panel>
        <Panel label="How it felt">{brief.emotionalSummary}</Panel>
        <Panel label="What they did">{brief.behavioralSummary}</Panel>
        <Panel label="The connection">{brief.keyRelationship}</Panel>
      </div>

      <section className="mt-10">
        <h2 className="text-[13px] font-medium uppercase tracking-[0.16em] text-secondary">
          A plan for tomorrow
        </h2>
        <ol className="mt-4 flex flex-col gap-2">
          {brief.recommendedPlan.map((step, i) => (
            <li
              key={i}
              className="flex gap-3 rounded-card border border-ink-wash bg-white px-4 py-3"
            >
              <span className="text-[13px] font-medium text-ink-tint">{i + 1}</span>
              <span className="text-[15px] leading-relaxed text-ink-black">{step}</span>
            </li>
          ))}
        </ol>
      </section>

      {byGroup.size > 0 ? (
        <section className="mt-10">
          <h2 className="text-[13px] font-medium uppercase tracking-[0.16em] text-secondary">
            Who to check on
          </h2>
          <div className="mt-4 flex flex-col gap-3">
            {[...byGroup.entries()].map(([group, names]) => {
              const positive = POSITIVE_GROUPS.has(group);
              return (
                <div
                  key={group}
                  className="rounded-card border border-ink-wash bg-white p-4"
                >
                  <div className="flex items-center gap-2">
                    <span
                      className={
                        positive
                          ? "inline-block h-2 w-2 rounded-full bg-ink-tint"
                          : "inline-block h-2 w-2 rounded-full bg-warm"
                      }
                      aria-hidden
                    />
                    <p className="text-[14px] font-medium text-ink-black">
                      {GROUP_LABELS[group]}
                    </p>
                  </div>
                  <p className="mt-2 text-[14px] text-secondary">{names.join(", ")}</p>
                </div>
              );
            })}
          </div>
        </section>
      ) : null}
    </>
  );
}

/**
 * Students whose own words suggest something OUTSIDE school is making school
 * harder. Warm accent, never red; framed as an observation with the student's own
 * words, plus a gentle steer — check in privately, or loop in the counselor. Never
 * a diagnosis, and separate from the crisis path.
 */
function ExternalFactors({ flags }: { flags: ExternalFactorFlags }): ReactElement {
  return (
    <section className="mt-10">
      <h2 className="text-[13px] font-medium uppercase tracking-[0.16em] text-secondary">
        Something outside class may be in the way
      </h2>
      <p className="mt-2 text-[14px] text-secondary">
        In their own words, {flags.students.length === 1 ? "this student" : "these students"}{" "}
        mentioned something outside school that may be making it harder to focus. A quiet,
        private check-in is often the right first step — and if it seems beyond a
        classroom conversation, {flags.counselorName} (counselor) can help.
      </p>
      <div className="mt-4 flex flex-col gap-3">
        {flags.students.map((s) => (
          <div key={s.studentId} className="rounded-card border border-ink-wash bg-white p-4">
            <div className="flex items-center gap-2">
              <span aria-hidden className="inline-block h-2 w-2 rounded-full bg-warm" />
              <p className="text-[15px] font-medium text-ink-black">{s.name}</p>
            </div>
            <p className="mt-2 text-[13px] text-secondary">
              Mentioned: {s.factors.join("; ")}
            </p>
            <blockquote className="mt-2 border-l-2 border-ink-wash pl-3 text-[14px] italic leading-relaxed text-ink-black">
              &ldquo;{s.excerpt}&rdquo;
            </blockquote>
          </div>
        ))}
      </div>
    </section>
  );
}

/** A titled list of students who made a given student-initiated request. */
function RequestList({
  label,
  note,
  requests,
}: {
  label: string;
  note: string;
  requests: HelpRequest[];
}): ReactElement {
  return (
    <section className="mt-10">
      <h2 className="text-[13px] font-medium uppercase tracking-[0.16em] text-secondary">
        {label}
      </h2>
      <p className="mt-2 text-[14px] text-secondary">{note}</p>
      <div className="mt-4 flex flex-col gap-2">
        {requests.map((r) => (
          <div
            key={r.studentId}
            className="flex items-center gap-2 rounded-card border border-ink-wash bg-white px-4 py-3"
          >
            <span
              aria-hidden
              className="inline-block h-2 w-2 rounded-full bg-ink-tint"
            />
            <p className="text-[15px] text-ink-black">{r.name}</p>
          </div>
        ))}
      </div>
    </section>
  );
}

/** How many students have finished, are mid-conversation, or haven't started. */
function ProgressStrip({ progress }: { progress: ReflectionProgress }): ReactElement {
  const tiles: { label: string; value: number; dot: string }[] = [
    { label: "Finished", value: progress.completed, dot: "bg-ink-tint" },
    { label: "Working on it", value: progress.inProgress, dot: "bg-ink-wash" },
    { label: "Not started", value: progress.notStarted, dot: "bg-ink-wash" },
  ];
  return (
    <section className="mt-8">
      <h2 className="text-[13px] font-medium uppercase tracking-[0.16em] text-secondary">
        Who&rsquo;s done it
      </h2>
      <div className="mt-3 grid grid-cols-3 gap-3">
        {tiles.map((t) => (
          <div key={t.label} className="rounded-card border border-ink-wash bg-white p-4">
            <span
              aria-hidden
              className={`inline-block h-2 w-2 rounded-full ${t.dot}`}
            />
            <p className="mt-2 text-3xl font-medium tabular-nums text-ink-black">
              {t.value}
            </p>
            <p className="mt-1 text-[13px] text-secondary">{t.label}</p>
          </div>
        ))}
      </div>
      <p className="mt-2 text-[12px] text-secondary">
        Out of {progress.rosterCount} student{progress.rosterCount === 1 ? "" : "s"} in
        the class.
      </p>
    </section>
  );
}

/**
 * The concept(s) a lot of students are struggling with, read from their own words
 * across the finished reflections. Struggle carries the warm accent, never red;
 * each flag names the students it rests on, so it reads as evidence, not a verdict.
 */
function StrugglingConcepts({
  view,
}: {
  view: StrugglingConceptsView;
}): ReactElement {
  return (
    <section className="mt-10">
      <h2 className="text-[13px] font-medium uppercase tracking-[0.16em] text-secondary">
        Where the class is getting stuck
      </h2>
      <p className="mt-2 text-[14px] text-secondary">
        Concepts several students named while describing what was hard — from their own
        words across {view.completedCount} reflection
        {view.completedCount === 1 ? "" : "s"}.
      </p>
      <div className="mt-4 flex flex-col gap-3">
        {view.concepts.map((c) => (
          <div
            key={c.concept}
            className="rounded-card border border-ink-wash bg-white p-4"
          >
            <div className="flex items-center gap-2">
              <span
                aria-hidden
                className="inline-block h-2 w-2 rounded-full bg-warm"
              />
              <p className="text-[15px] font-medium text-ink-black">
                {capitalizeFirst(c.concept)}
              </p>
            </div>
            <p className="mt-2 text-[14px] text-secondary">
              {c.studentCount} of {view.completedCount} student
              {view.completedCount === 1 ? "" : "s"} who reflected showed difficulty
              here — {c.studentNames.join(", ")}.
            </p>
          </div>
        ))}
      </div>
    </section>
  );
}

function capitalizeFirst(text: string): string {
  return text.length === 0 ? text : text.charAt(0).toUpperCase() + text.slice(1);
}

function BackLink(): ReactElement {
  return (
    <Link href="/lessons" className="text-[13px] text-ink-tint hover:underline">
      ← All reflections
    </Link>
  );
}

function Panel({
  label,
  children,
}: {
  label: string;
  children: React.ReactNode;
}): ReactElement {
  return (
    <div className="rounded-card border border-ink-wash bg-white p-5">
      <p className="text-[12px] font-medium uppercase tracking-[0.16em] text-secondary">
        {label}
      </p>
      <p className="mt-2 text-[15px] leading-relaxed text-ink-black">{children}</p>
    </div>
  );
}
