"use client";

import { useState } from "react";
import { createPrediction } from "@/domain/prediction";
import { createOutcome } from "@/domain/outcome";
import { calibrate, type Calibration } from "@/domain/calibration";

/**
 * First vertical slice of the academic loop: a student pre-registers confidence,
 * the truth is revealed, and their calibration is computed. Feedback is
 * TASK-focused; accuracy is shown with ink-tint (aligned) / warm (gap) — never
 * green/red. No gamified rewards. AI is not involved: calibration is deterministic.
 */

interface Item {
  readonly id: string;
  readonly statement: string;
  readonly isTrue: boolean;
}

const ITEMS: readonly Item[] = [
  { id: "q1", statement: "The Earth orbits the Sun.", isTrue: true },
  { id: "q2", statement: "A triangle has four sides.", isTrue: false },
  { id: "q3", statement: "Water boils at 100°C at sea level.", isTrue: true },
];

type Answer = boolean | null;

function biasSentence(bias: number): string {
  if (bias > 0.1) {
    return "Your confidence ran ahead of your results on these items.";
  }
  if (bias < -0.1) {
    return "Your results ran ahead of your confidence — you knew more than you claimed.";
  }
  return "Your confidence and your results lined up closely here.";
}

export default function CalibrationDemo(): React.ReactElement {
  const [answers, setAnswers] = useState<Record<string, Answer>>({
    q1: null,
    q2: null,
    q3: null,
  });
  const [confidence, setConfidence] = useState<Record<string, number>>({
    q1: 50,
    q2: 50,
    q3: 50,
  });
  const [predictedScore, setPredictedScore] = useState<number>(50);
  const [result, setResult] = useState<Calibration | null>(null);
  const [hint, setHint] = useState<string | null>(null);

  const allAnswered = ITEMS.every((it) => answers[it.id] !== null);

  function reveal(): void {
    if (!allAnswered) {
      setHint("Mark true or false for each statement first.");
      return;
    }
    setHint(null);

    const prediction = createPrediction({
      items: ITEMS.map((it) => ({
        itemId: it.id,
        confidence: confidence[it.id] / 100,
      })),
      predictedScore: predictedScore / 100,
    });
    const outcome = createOutcome({
      items: ITEMS.map((it) => ({
        itemId: it.id,
        correct: answers[it.id] === it.isTrue,
      })),
    });
    setResult(calibrate(prediction, outcome));
  }

  function restart(): void {
    setAnswers({ q1: null, q2: null, q3: null });
    setConfidence({ q1: 50, q2: 50, q3: 50 });
    setPredictedScore(50);
    setResult(null);
    setHint(null);
  }

  // ── Reveal / result view ──────────────────────────────────────────────
  if (result) {
    return (
      <section className="rounded-card border border-ink-wash bg-white p-6">
        <h2 className="text-lg font-semibold text-ink">Where am I really?</h2>
        <p className="mt-1 text-sm text-secondary">
          How your confidence lined up with what actually happened.
        </p>

        <ul className="mt-5 space-y-3">
          {ITEMS.map((it) => {
            const correct = answers[it.id] === it.isTrue;
            const conf = confidence[it.id] / 100;
            const gap = Math.abs(conf - (correct ? 1 : 0));
            const aligned = gap <= 0.25;
            return (
              <li
                key={it.id}
                className="rounded-control border border-ink-wash p-3"
              >
                <p className="text-sm text-ink-black">{it.statement}</p>
                <div className="mt-1 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-secondary">
                  <span>You said: {answers[it.id] ? "True" : "False"}</span>
                  <span>Actually: {it.isTrue ? "True" : "False"}</span>
                  <span>Confidence: {confidence[it.id]}%</span>
                  <span className="inline-flex items-center gap-1.5">
                    <span
                      aria-hidden
                      className="inline-block h-2 w-2 rounded-full"
                      style={{
                        backgroundColor: aligned
                          ? "var(--color-ink-tint)"
                          : "var(--color-warm)",
                      }}
                    />
                    {aligned ? "confidence aligned" : "confidence gap"}
                  </span>
                </div>
              </li>
            );
          })}
        </ul>

        <div className="mt-5 rounded-control bg-ink-wash p-4">
          <p className="text-sm text-ink-black">{biasSentence(result.bias)}</p>
          <dl className="mt-3 grid grid-cols-2 gap-3 text-sm">
            <div>
              <dt className="text-xs text-secondary">Brier score (lower is closer)</dt>
              <dd className="font-semibold text-ink tabular-nums">
                {result.brier.toFixed(2)}
              </dd>
            </div>
            <div>
              <dt className="text-xs text-secondary">
                Confidence vs. results (bias)
              </dt>
              <dd className="font-semibold text-ink tabular-nums">
                {result.bias >= 0 ? "+" : ""}
                {result.bias.toFixed(2)}
              </dd>
            </div>
          </dl>
        </div>

        <button
          type="button"
          onClick={restart}
          className="mt-5 rounded-control border border-ink-tint px-4 py-2 text-sm font-medium text-ink transition-colors hover:bg-ink-wash"
        >
          Try again
        </button>
      </section>
    );
  }

  // ── Prediction view ──────────────────────────────────────────────────
  return (
    <section className="rounded-card border border-ink-wash bg-white p-6">
      <h2 className="text-lg font-semibold text-ink">Before you see the answers</h2>
      <p className="mt-1 text-sm text-secondary">
        Mark each statement, then set how confident you are that you&apos;re right.
        Your prediction is captured before the truth is revealed.
      </p>

      <ul className="mt-5 space-y-4">
        {ITEMS.map((it) => (
          <li key={it.id} className="rounded-control border border-ink-wash p-4">
            <p className="text-sm text-ink-black">{it.statement}</p>
            <div className="mt-3 flex gap-2" role="group" aria-label={it.statement}>
              {([true, false] as const).map((val) => {
                const active = answers[it.id] === val;
                return (
                  <button
                    key={String(val)}
                    type="button"
                    aria-pressed={active}
                    onClick={() =>
                      setAnswers((a) => ({ ...a, [it.id]: val }))
                    }
                    className={`rounded-control px-4 py-1.5 text-sm font-medium transition-colors ${
                      active
                        ? "bg-ink text-white"
                        : "border border-ink-wash text-ink hover:bg-ink-wash"
                    }`}
                  >
                    {val ? "True" : "False"}
                  </button>
                );
              })}
            </div>
            <label className="mt-3 block text-xs text-secondary">
              Confidence you&apos;re right: {confidence[it.id]}%
              <input
                type="range"
                min={0}
                max={100}
                step={5}
                value={confidence[it.id]}
                onChange={(e) =>
                  setConfidence((c) => ({
                    ...c,
                    [it.id]: Number(e.target.value),
                  }))
                }
                className="mt-1 block w-full accent-[color:var(--color-ink-tint)]"
              />
            </label>
          </li>
        ))}
      </ul>

      <label className="mt-5 block text-sm text-ink-black">
        Overall, what share of the three will you get right? {predictedScore}%
        <input
          type="range"
          min={0}
          max={100}
          step={5}
          value={predictedScore}
          onChange={(e) => setPredictedScore(Number(e.target.value))}
          className="mt-1 block w-full accent-[color:var(--color-ink-tint)]"
        />
      </label>

      {hint && <p className="mt-3 text-sm text-ink-tint">{hint}</p>}

      <button
        type="button"
        onClick={reveal}
        className="mt-5 rounded-control bg-ink px-5 py-2.5 text-sm font-semibold text-white transition-opacity hover:opacity-90"
      >
        Reveal the answers
      </button>
    </section>
  );
}
