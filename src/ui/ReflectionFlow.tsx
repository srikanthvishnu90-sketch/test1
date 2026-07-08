"use client";

import { useState } from "react";
import WrongItemStep from "./WrongItemStep";
import FinalReflection from "./FinalReflection";

/**
 * Orchestrates the self-reflection phase: walk through EVERY missed question one
 * at a time, then a closing reflection on the whole score, then done. Kept in a
 * cold, calm, reward-free sequence (per CLAUDE.md's hot/cold note).
 */

export interface WrongItem {
  readonly id: string;
  readonly statement: string;
  readonly correctAnswerText: string;
  readonly probe: { readonly statement: string; readonly isTrue: boolean };
}

type Phase = "items" | "final" | "done";

interface Props {
  readonly wrongItems: readonly WrongItem[];
  readonly predictedPct: number;
  readonly actualPct: number;
}

export default function ReflectionFlow({
  wrongItems,
  predictedPct,
  actualPct,
}: Props): React.ReactElement {
  const [phase, setPhase] = useState<Phase>(
    wrongItems.length > 0 ? "items" : "final",
  );
  const [index, setIndex] = useState<number>(0);

  function advance(): void {
    if (index + 1 < wrongItems.length) {
      setIndex(index + 1);
    } else {
      setPhase("final");
    }
  }

  if (phase === "items") {
    const item = wrongItems[index];
    return (
      <WrongItemStep
        key={item.id}
        index={index}
        total={wrongItems.length}
        statement={item.statement}
        correctAnswerText={item.correctAnswerText}
        probe={item.probe}
        onDone={advance}
      />
    );
  }

  if (phase === "final") {
    return (
      <FinalReflection
        predictedPct={predictedPct}
        actualPct={actualPct}
        hadMiss={wrongItems.length > 0}
        onDone={() => setPhase("done")}
      />
    );
  }

  return (
    <div className="mt-4 rounded-card border border-ink-wash bg-white p-5">
      <p className="text-sm text-ink-black">
        That&apos;s a full loop — predicted, checked, reviewed, and reflected.
      </p>
      <p className="mt-1 text-xs text-secondary">
        Your cycle is saved below. Run another whenever you want.
      </p>
    </div>
  );
}
