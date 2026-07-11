"use client";

import { useRouter } from "next/navigation";
import { useState, useTransition, type ReactElement } from "react";
import {
  createLessonReflection,
  previewReflectionSurvey,
} from "@/app/_world/teacherReflectionActions";
import type {
  NewLessonInput,
  SurveyPreview,
  SurveyPreviewQuestion,
} from "@/app/_world/teacherReflectionActions";
import type { LessonType } from "@/domain/intelligence/lesson";

type Depth = "shorter" | "standard" | "deeper";

const DEPTHS: { value: Depth; label: string }[] = [
  { value: "shorter", label: "Shorter" },
  { value: "standard", label: "Standard" },
  { value: "deeper", label: "Deeper" },
];

/** Quick-reply scales the student taps — mirrors the real reflection chat. */
const SCALE_LABELS: Record<string, string[]> = {
  rating: ["Not at all", "A little", "Somewhat", "Mostly", "Completely"],
  confidence_slider: ["Not yet", "A little", "Somewhat", "Confident", "Very confident"],
};

/** Keep in sync with lessonMedia.MAX_PHOTOS (server enforces the real cap). */
const MAX_PHOTOS = 6;

/**
 * The teacher's lesson entry. A few lines about what happened in class is enough;
 * the AI reads it and drafts the reflection. No pre-assessment, no scoring here —
 * just the seed the whole loop grows from.
 */

const LESSON_TYPES: { value: LessonType; label: string }[] = [
  { value: "direct_instruction", label: "Direct instruction" },
  { value: "discussion", label: "Discussion" },
  { value: "group_work", label: "Group work" },
  { value: "independent_practice", label: "Independent practice" },
  { value: "lab", label: "Lab" },
  { value: "presentation", label: "Presentation" },
  { value: "project", label: "Project" },
  { value: "review", label: "Review" },
  { value: "assessment_prep", label: "Assessment prep" },
  { value: "other", label: "Other" },
];

function readAsDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(reader.result as string);
    reader.onerror = () => reject(reader.error);
    reader.readAsDataURL(file);
  });
}

export default function NewLessonForm(): ReactElement {
  const router = useRouter();
  const [title, setTitle] = useState("");
  const [lessonType, setLessonType] = useState<LessonType>("direct_instruction");
  const [content, setContent] = useState("");
  const [photos, setPhotos] = useState<string[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [pending, startTransition] = useTransition();
  const [survey, setSurvey] = useState<SurveyPreview | null>(null);
  const [previewError, setPreviewError] = useState<string | null>(null);
  const [depth, setDepth] = useState<Depth>("standard");
  const [previewing, startPreview] = useTransition();

  async function addPhotos(files: FileList | null): Promise<void> {
    if (files === null) return;
    const images = [...files].filter((f) => f.type.startsWith("image/"));
    const urls = await Promise.all(images.map(readAsDataUrl));
    setPhotos((prev) => [...prev, ...urls].slice(0, MAX_PHOTOS));
  }

  function removePhoto(index: number): void {
    setPhotos((prev) => prev.filter((_, i) => i !== index));
  }

  function submit(): void {
    setError(null);
    const input: NewLessonInput = { title, lessonType, content, photos };
    startTransition(async () => {
      try {
        const reflectionId = await createLessonReflection(input);
        router.push(`/lessons/${reflectionId}`);
      } catch (e) {
        setError(e instanceof Error ? e.message : "Something went wrong.");
      }
    });
  }

  function runPreview(nextDepth: Depth): void {
    setPreviewError(null);
    if (title.trim().length === 0) {
      setPreviewError("Add a lesson title to preview the survey.");
      return;
    }
    setDepth(nextDepth);
    startPreview(async () => {
      try {
        const result = await previewReflectionSurvey({
          title,
          lessonType,
          content,
          depth: nextDepth,
        });
        setSurvey(result);
      } catch (e) {
        setPreviewError(e instanceof Error ? e.message : "Couldn't generate a preview.");
      }
    });
  }

  return (
    <div className="rounded-card border border-ink-wash bg-white p-6">
      <label className="block text-[13px] font-medium text-ink-black" htmlFor="title">
        Lesson title
      </label>
      <input
        id="title"
        value={title}
        onChange={(e) => setTitle(e.target.value)}
        placeholder="Factoring quadratic equations"
        className="mt-2 w-full rounded-control border border-ink-wash bg-white px-3 py-2 text-[15px] text-ink-black outline-none focus:border-ink-tint"
      />

      <label className="mt-5 block text-[13px] font-medium text-ink-black" htmlFor="type">
        What kind of class was it?
      </label>
      <select
        id="type"
        value={lessonType}
        onChange={(e) => setLessonType(e.target.value as LessonType)}
        className="mt-2 w-full rounded-control border border-ink-wash bg-white px-3 py-2 text-[15px] text-ink-black outline-none focus:border-ink-tint"
      >
        {LESSON_TYPES.map((t) => (
          <option key={t.value} value={t.value}>
            {t.label}
          </option>
        ))}
      </select>

      <label className="mt-5 block text-[13px] font-medium text-ink-black" htmlFor="content">
        What happened in class?
      </label>
      <p className="mt-1 text-[13px] text-secondary">
        A few lines is plenty — what you taught, what students did, where it got hard.
      </p>
      <textarea
        id="content"
        value={content}
        onChange={(e) => setContent(e.target.value)}
        rows={5}
        placeholder="I modeled three examples, then students factored six on their own. The sign on the middle term tripped a lot of them up."
        className="mt-2 w-full resize-none rounded-control border border-ink-wash bg-white px-3 py-2 text-[15px] leading-relaxed text-ink-black outline-none focus:border-ink-tint"
      />

      <label className="mt-5 block text-[13px] font-medium text-ink-black">
        Photos of the day (optional)
      </label>
      <p className="mt-1 text-[13px] text-secondary">
        Board work, an anchor chart, student work — up to {MAX_PHOTOS}.
      </p>
      <div className="mt-2 flex flex-wrap gap-2">
        {photos.map((src, i) => (
          <div key={i} className="relative">
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img
              src={src}
              alt={`Lesson photo ${i + 1}`}
              className="h-20 w-20 rounded-control border border-ink-wash object-cover"
            />
            <button
              type="button"
              onClick={() => removePhoto(i)}
              aria-label={`Remove photo ${i + 1}`}
              className="absolute -right-1.5 -top-1.5 flex h-5 w-5 items-center justify-center rounded-full border border-ink-wash bg-white text-[12px] leading-none text-ink-black shadow-sm hover:border-ink-tint"
            >
              ×
            </button>
          </div>
        ))}
        {photos.length < MAX_PHOTOS && (
          <label className="flex h-20 w-20 cursor-pointer items-center justify-center rounded-control border border-dashed border-ink-wash text-[13px] text-secondary transition-colors hover:border-ink-tint hover:text-ink-tint">
            + Add
            <input
              type="file"
              accept="image/*"
              multiple
              className="hidden"
              onChange={(e) => {
                void addPhotos(e.target.files);
                e.target.value = "";
              }}
            />
          </label>
        )}
      </div>

      {error !== null ? (
        <p className="mt-3 text-[13px] text-ink-black">{error}</p>
      ) : null}

      <div className="mt-5 flex flex-wrap items-center gap-3">
        <button
          type="button"
          disabled={pending || title.trim().length === 0 || content.trim().length === 0}
          onClick={submit}
          className="rounded-control bg-ink px-5 py-2.5 text-sm font-medium text-white transition-colors hover:bg-ink-tint disabled:opacity-40"
        >
          {pending ? "Reading the lesson…" : "Create reflection"}
        </button>
        <button
          type="button"
          disabled={previewing || title.trim().length === 0}
          onClick={() => runPreview(depth)}
          className="rounded-control border border-ink-wash px-5 py-2.5 text-sm font-medium text-ink-black transition-colors hover:border-ink-tint disabled:opacity-40"
        >
          {previewing
            ? "Generating…"
            : survey !== null
              ? "Refresh preview"
              : "Preview survey"}
        </button>
        <span className="text-[12px] text-secondary">
          See the questions students would get — nothing is saved.
        </span>
      </div>

      {previewError !== null ? (
        <p className="mt-3 text-[13px] text-ink-black">{previewError}</p>
      ) : null}

      {survey !== null ? (
        <SurveyPreviewCard
          survey={survey}
          depth={depth}
          onDepth={runPreview}
          pending={previewing}
        />
      ) : null}
    </div>
  );
}

/** The generated survey, rendered as students see it (question + answer control). */
function SurveyPreviewCard({
  survey,
  depth,
  onDepth,
  pending,
}: {
  survey: SurveyPreview;
  depth: Depth;
  onDepth: (d: Depth) => void;
  pending: boolean;
}): ReactElement {
  return (
    <div className="mt-6 overflow-hidden rounded-card border border-ink-wash bg-paper">
      <div className="flex flex-wrap items-center gap-3 border-b border-ink-wash bg-white px-4 py-3">
        <span className="flex h-7 w-7 items-center justify-center rounded-full bg-ink text-[12px] font-medium text-white">
          p
        </span>
        <div>
          <p className="text-[13px] font-medium leading-none text-ink-black">
            Survey preview
          </p>
          <p className="mt-0.5 text-[12px] text-secondary">
            What the student would be asked · {survey.questions.length} questions
          </p>
        </div>
        <div
          className="ml-auto flex overflow-hidden rounded-control border border-ink-wash"
          role="group"
          aria-label="Survey length"
        >
          {DEPTHS.map((d) => {
            const active = d.value === depth;
            return (
              <button
                key={d.value}
                type="button"
                disabled={pending}
                onClick={() => onDepth(d.value)}
                className={`px-3 py-1.5 text-[12px] font-medium transition-colors disabled:opacity-50 ${
                  active
                    ? "bg-ink text-white"
                    : "bg-white text-secondary hover:bg-ink-wash"
                }`}
              >
                {d.label}
              </button>
            );
          })}
        </div>
      </div>

      <ol className="flex flex-col gap-5 px-4 py-5">
        {survey.questions.map((q, i) => (
          <li key={i} className="flex flex-col gap-2.5">
            <div className="flex items-baseline gap-2.5">
              <span className="min-w-[14px] text-[12px] font-medium tabular-nums text-secondary">
                {i + 1}
              </span>
              <span className="text-[15px] font-medium leading-snug text-ink-black">
                {q.text}
              </span>
            </div>
            <div className="pl-[26px]">
              <AnswerControl question={q} />
            </div>
          </li>
        ))}
      </ol>

      <p className="border-t border-ink-wash px-4 py-3 text-[12px] text-secondary">
        {survey.adaptiveFollowups
          ? `Can branch into up to ${survey.maxFollowups} adaptive follow-ups based on answers.`
          : "No adaptive follow-ups."}
      </p>
    </div>
  );
}

/** Render the answer widget a given question format uses. */
function AnswerControl({ question }: { question: SurveyPreviewQuestion }): ReactElement {
  const scale = SCALE_LABELS[question.format];
  const chips =
    scale ??
    (question.options && question.options.length > 0 ? question.options : null);
  if (chips !== null) {
    return (
      <div className="flex flex-wrap gap-2">
        {chips.map((c) => (
          <span
            key={c}
            className="rounded-full border border-ink-wash bg-white px-3.5 py-1.5 text-[13px] text-ink-black"
          >
            {c}
          </span>
        ))}
      </div>
    );
  }
  return (
    <div className="rounded-2xl border border-ink-wash bg-white px-4 py-2.5 text-[13px] text-secondary">
      Message… — a sentence or two in your own words
    </div>
  );
}
