"use client";

import { useState } from "react";
import {
  createReflection,
  causeLabel,
  CAUSES,
  type Reflection,
} from "@/domain/reflection";
import TransferProbeStep from "./TransferProbeStep";

/**
 * One missed question, reviewed thoroughly: reflect against the correct exemplar
 * (Kluger & DeNisi: reflect on the right answer, not the wrong one), pick a
 * controllable cause or write your own specific reason, commit a concrete next
 * step, then a transfer check. Task-focused; ink-tint/warm, never green/red.
 */

function tomorrowISO(): string {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  return d.toISOString().slice(0, 10);
}

interface Props {
  readonly index: number;
  readonly total: number;
  readonly statement: string;
  readonly correctAnswerText: string;
  readonly probe: { readonly statement: string; readonly isTrue: boolean };
  readonly onDone: (reflection: Reflection) => void;
}

export default function WrongItemStep({
  index,
  total,
  statement,
  correctAnswerText,
  probe,
  onDone,
}: Props): React.ReactElement {
  const [causeId, setCauseId] = useState<string>("");
  const [otherText, setOtherText] = useState<string>("");
  const [nextAction, setNextAction] = useState<string>("");
  const [dueDate, setDueDate] = useState<string>(tomorrowISO());
  const [committed, setCommitted] = useState<Reflection | null>(null);
  const [probeChecked, setProbeChecked] = useState<boolean>(false);
  const [hint, setHint] = useState<string | null>(null);

  function commit(): void {
    try {
      setCommitted(createReflection({ causeId, otherText, nextAction, dueDate }));
      setHint(null);
    } catch (e) {
      setHint(e instanceof Error ? e.message : "Please complete this first.");
    }
  }

  return (
    <div className="mt-4 rounded-card border border-ink-wash bg-white p-5">
      <p className="text-xs font-semibold uppercase tracking-wide text-ink-tint">
        Revisit {index + 1} of {total}
      </p>
      <p className="mt-2 text-sm text-ink-black">
        The correct answer is <strong>{correctAnswerText}</strong>:
      </p>
      <p className="mt-1 text-sm text-secondary">&ldquo;{statement}&rdquo;</p>

      {!committed ? (
        <>
          <fieldset className="mt-4">
            <legend className="text-xs text-secondary">
              What got in the way? (pick the closest, or say your own)
            </legend>
            <div className="mt-2 space-y-1.5">
              {CAUSES.map((c) => (
                <label
                  key={c.id}
                  className="flex items-center gap-2 text-sm text-ink-black"
                >
                  <input
                    type="radio"
                    name={`cause-${index}`}
                    value={c.id}
                    checked={causeId === c.id}
                    onChange={() => setCauseId(c.id)}
                    className="accent-[color:var(--color-ink-tint)]"
                  />
                  {c.label}
                </label>
              ))}
            </div>

            {causeId === "other" && (
              <input
                type="text"
                value={otherText}
                autoFocus
                onChange={(e) => setOtherText(e.target.value)}
                placeholder="In your own words — what specifically happened?"
                className="mt-2 block w-full rounded-control border border-ink-wash px-3 py-2 text-sm text-ink-black"
              />
            )}
          </fieldset>

          <label className="mt-4 block text-xs text-secondary">
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
            Save this
          </button>
        </>
      ) : (
        <>
          <div className="mt-4 rounded-control border border-ink-tint bg-ink-wash p-3">
            <p className="text-sm text-ink-black">{committed.nextAction}</p>
            <p className="mt-1 text-xs text-secondary">
              By {committed.dueDate} · because{" "}
              {committed.causeId === "other" && committed.otherText
                ? committed.otherText.toLowerCase()
                : causeLabel(committed.causeId).toLowerCase()}
            </p>
          </div>

          <TransferProbeStep
            probe={probe}
            onChecked={() => setProbeChecked(true)}
          />

          {probeChecked && (
            <button
              type="button"
              onClick={() => onDone(committed)}
              className="mt-4 rounded-control bg-ink px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90"
            >
              {index + 1 < total ? "Next question" : "Last look back"}
            </button>
          )}
        </>
      )}
    </div>
  );
}
