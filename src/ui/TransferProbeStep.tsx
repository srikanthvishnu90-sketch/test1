"use client";

import { useState } from "react";
import { scoreProbe, type ProbeResult } from "@/domain/transferProbe";

/**
 * Transfer check: a fresh item after the reflection, to test real transfer vs.
 * the fluency illusion. Result uses ink-tint (transferred) / warm (not yet) —
 * never green/red — and task-focused copy.
 */

interface Props {
  readonly probe: { readonly statement: string; readonly isTrue: boolean };
  readonly onChecked?: (transferred: boolean) => void;
}

export default function TransferProbeStep({
  probe,
  onChecked,
}: Props): React.ReactElement {
  const [answer, setAnswer] = useState<boolean | null>(null);
  const [result, setResult] = useState<ProbeResult | null>(null);

  function check(): void {
    if (answer === null) return;
    const scored = scoreProbe(
      { id: "probe", statement: probe.statement, isTrue: probe.isTrue },
      answer,
    );
    setResult(scored);
    onChecked?.(scored.transferred);
  }

  if (result) {
    const transferred = result.transferred;
    return (
      <div
        className="mt-4 rounded-control border p-4"
        style={{
          borderColor: transferred
            ? "var(--color-ink-tint)"
            : "var(--color-warm)",
        }}
      >
        <p className="text-xs font-semibold uppercase tracking-wide text-ink-tint">
          Transfer check
        </p>
        <p className="mt-2 text-sm text-ink-black">
          {transferred
            ? "You carried it over to a fresh question — that’s real transfer."
            : "Not yet — the sense of “getting it” ran ahead of a fresh question. Worth another pass."}
        </p>
      </div>
    );
  }

  return (
    <div className="mt-4 rounded-control border border-ink-wash p-4">
      <p className="text-xs font-semibold uppercase tracking-wide text-ink-tint">
        Transfer check
      </p>
      <p className="mt-2 text-sm text-ink-black">A fresh one, to see if it stuck:</p>
      <p className="mt-1 text-sm text-secondary">&ldquo;{probe.statement}&rdquo;</p>

      <div className="mt-3 flex gap-2" role="group" aria-label={probe.statement}>
        {([true, false] as const).map((val) => {
          const active = answer === val;
          return (
            <button
              key={String(val)}
              type="button"
              aria-pressed={active}
              onClick={() => setAnswer(val)}
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

      <button
        type="button"
        onClick={check}
        disabled={answer === null}
        className="mt-3 rounded-control bg-ink px-4 py-2 text-sm font-semibold text-white transition-opacity hover:opacity-90 disabled:opacity-50"
      >
        Check
      </button>
    </div>
  );
}
