"use client";

import { useState } from "react";
import {
  createScoreReflection,
  questionsFor,
  type ScoreReflection,
} from "@/domain/scoreReflection";

/**
 * Closing metacognitive reflection on the whole score. Prompts are anchored to
 * the student's own numbers and modeled with example answers (scaffolding the
 * blank page raises response quality). Answering is optional (autonomy, SDT) —
 * we invite, we don't force.
 */

interface Props {
  readonly predictedPct: number;
  readonly actualPct: number;
  readonly hadMiss: boolean;
  readonly onSaved: (scoreReflection: ScoreReflection) => void;
  readonly onDone: () => void;
}

export default function FinalReflection({
  predictedPct,
  actualPct,
  hadMiss,
  onSaved,
  onDone,
}: Props): React.ReactElement {
  const questions = questionsFor(hadMiss);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [saved, setSaved] = useState<ScoreReflection | null>(null);

  function fill(prompt: string): string {
    return prompt
      .replace("{predicted}", String(predictedPct))
      .replace("{actual}", String(actualPct));
  }

  function submit(): void {
    const reflection = createScoreReflection(answers);
    setSaved(reflection);
    onSaved(reflection);
  }

  if (saved) {
    const count = Object.keys(saved.answers).length;
    return (
      <div className="mt-4 rounded-card border border-ink-tint bg-ink-wash p-5">
        <p className="text-xs font-semibold uppercase tracking-wide text-ink-tint">
          One last look back
        </p>
        <p className="mt-2 text-sm text-ink-black">
          {count > 0
            ? "Saved. Naming how you worked is the part that actually moves your next score."
            : "That's okay — you can come back to these anytime."}
        </p>
        <button
          type="button"
          onClick={onDone}
          className="mt-4 rounded-control bg-ink px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
        >
          Done
        </button>
      </div>
    );
  }

  return (
    <div className="mt-4 rounded-card border border-ink-wash bg-white p-5">
      <p className="text-xs font-semibold uppercase tracking-wide text-ink-tint">
        One last look back
      </p>
      <p className="mt-1 text-sm text-secondary">
        A few short ones about how it went. No wrong answers here — write like
        you&apos;re talking to yourself.
      </p>

      <div className="mt-4 space-y-5">
        {questions.map((q) => (
          <div key={q.id}>
            <label
              htmlFor={`sr-${q.id}`}
              className="block text-sm text-ink-black"
            >
              {fill(q.prompt)}
            </label>
            <p className="mt-1 text-xs text-secondary">{q.helper}</p>
            <textarea
              id={`sr-${q.id}`}
              rows={2}
              value={answers[q.id] ?? ""}
              onChange={(e) =>
                setAnswers((a) => ({ ...a, [q.id]: e.target.value }))
              }
              className="mt-2 block w-full resize-y rounded-control border border-ink-wash px-3 py-2 text-sm text-ink-black"
            />
          </div>
        ))}
      </div>

      <button
        type="button"
        onClick={submit}
        className="mt-5 rounded-control bg-ink px-5 py-2.5 text-sm font-semibold text-white transition-opacity hover:opacity-90"
      >
        Save my reflection
      </button>
    </div>
  );
}
