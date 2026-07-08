"use client";

import { useState } from "react";
import type { Reflection } from "@/domain/reflection";
import type { ScoreReflection } from "@/domain/scoreReflection";
import type { CycleReflections } from "@/domain/cycle";
import WrongItemStep from "./WrongItemStep";
import FinalReflection from "./FinalReflection";

/**
 * Orchestrates the self-reflection phase: walk through EVERY missed question one
 * at a time, then a closing reflection on the whole score. Accumulates the
 * reflections and reports them up (onReflections) so they can be persisted onto
 * the saved cycle. Kept in a cold, calm, reward-free sequence.
 */

export interface WrongItem {
  readonly id: string;
  readonly statement: string;
  readonly correctAnswerText: string;
}

type Phase = "items" | "final" | "done";

interface Props {
  readonly wrongItems: readonly WrongItem[];
  readonly predictedPct: number;
  readonly actualPct: number;
  readonly onReflections: (reflections: CycleReflections) => void;
}

export default function ReflectionFlow({
  wrongItems,
  predictedPct,
  actualPct,
  onReflections,
}: Props): React.ReactElement {
  const [phase, setPhase] = useState<Phase>(
    wrongItems.length > 0 ? "items" : "final",
  );
  const [index, setIndex] = useState<number>(0);
  const [itemReflections, setItemReflections] = useState<readonly Reflection[]>(
    [],
  );

  function completeItem(reflection: Reflection): void {
    const next = [...itemReflections, reflection];
    setItemReflections(next);
    onReflections({ itemReflections: next, scoreReflection: null });
    if (index + 1 < wrongItems.length) {
      setIndex(index + 1);
    } else {
      setPhase("final");
    }
  }

  function completeFinal(scoreReflection: ScoreReflection): void {
    onReflections({ itemReflections, scoreReflection });
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
        onDone={completeItem}
      />
    );
  }

  if (phase === "final") {
    return (
      <FinalReflection
        predictedPct={predictedPct}
        actualPct={actualPct}
        hadMiss={wrongItems.length > 0}
        onSaved={completeFinal}
        onDone={() => setPhase("done")}
      />
    );
  }

  return (
    <div className="mt-4 rounded-card border border-ink-wash bg-white p-5">
      <p className="text-sm text-ink-black">
        That&apos;s a full loop — you predicted, saw the truth, corrected each
        miss, and reflected on the score you got.
      </p>
      <p className="mt-1 text-xs text-secondary">
        Your score stands; the value is in the review. It&apos;s all saved below.
      </p>
    </div>
  );
}
