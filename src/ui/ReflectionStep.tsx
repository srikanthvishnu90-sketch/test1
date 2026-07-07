"use client";

import { useState } from "react";
import {
  createReflection,
  causeLabel,
  CAUSES,
  type Reflection,
} from "@/domain/reflection";

/**
 * Feed-forward step: reflect against the CORRECT exemplar, choose one
 * controllable+specific cause, and commit one concrete, dated next action.
 * Copy is task-focused; the cause list cannot express stable/global blame.
 */

function tomorrowISO(): string {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

interface Props {
  readonly focusStatement: string;
  readonly correctAnswerText: string;
  readonly onCommitted?: () => void;
}

export default function ReflectionStep({
  focusStatement,
  correctAnswerText,
  onCommitted,
}: Props): React.ReactElement {
  const [causeId, setCauseId] = useState<string>("");
  const [nextAction, setNextAction] = useState<string>("");
  const [dueDate, setDueDate] = useState<string>(tomorrowISO());
  const [committed, setCommitted] = useState<Reflection | null>(null);
  const [hint, setHint] = useState<string | null>(null);

  function commit(): void {
    try {
      setCommitted(createReflection({ causeId, nextAction, dueDate }));
      setHint(null);
      onCommitted?.();
    } catch (e) {
      setHint(e instanceof Error ? e.message : "Please complete the reflection.");
    }
  }

  if (committed) {
    return (
      <div className="mt-4 rounded-control border border-ink-tint bg-ink-wash p-4">
        <p className="text-xs font-semibold uppercase tracking-wide text-ink-tint">
          Where to next?
        </p>
        <p className="mt-2 text-sm text-ink-black">{committed.nextAction}</p>
        <p className="mt-1 text-xs text-secondary">
          By {committed.dueDate} · because{" "}
          {causeLabel(committed.causeId).toLowerCase()}
        </p>
      </div>
    );
  }

  return (
    <div className="mt-4 rounded-control border border-ink-wash p-4">
      <p className="text-xs font-semibold uppercase tracking-wide text-ink-tint">
        Where to next?
      </p>
      <p className="mt-2 text-sm text-ink-black">
        Reflect on this one — the correct answer is{" "}
        <strong>{correctAnswerText}</strong>:
      </p>
      <p className="mt-1 text-sm text-secondary">&ldquo;{focusStatement}&rdquo;</p>

      <fieldset className="mt-3">
        <legend className="text-xs text-secondary">
          What got in the way? (pick the closest)
        </legend>
        <div className="mt-2 space-y-1.5">
          {CAUSES.map((c) => (
            <label
              key={c.id}
              className="flex items-center gap-2 text-sm text-ink-black"
            >
              <input
                type="radio"
                name="cause"
                value={c.id}
                checked={causeId === c.id}
                onChange={() => setCauseId(c.id)}
                className="accent-[color:var(--color-ink-tint)]"
              />
              {c.label}
            </label>
          ))}
        </div>
      </fieldset>

      <label className="mt-3 block text-xs text-secondary">
        One concrete next step
        <input
          type="text"
          value={nextAction}
          onChange={(e) => setNextAction(e.target.value)}
          placeholder="e.g. Redo this kind of question and check each step"
          className="mt-1 block w-full rounded-control border border-ink-wash px-3 py-2 text-sm text-ink-black"
        />
      </label>

      <label className="mt-3 block text-xs text-secondary">
        By when
        <input
          type="date"
          value={dueDate}
          onChange={(e) => setDueDate(e.target.value)}
          className="mt-1 block rounded-control border border-ink-wash px-3 py-2 text-sm text-ink-black"
        />
      </label>

      {hint && <p className="mt-2 text-sm text-ink-tint">{hint}</p>}

      <button
        type="button"
        onClick={commit}
        className="mt-3 rounded-control bg-ink px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
      >
        Commit next step
      </button>
    </div>
  );
}
