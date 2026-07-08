/**
 * Reflection — the feed-forward output of a cycle: a CONTROLLABLE + SPECIFIC
 * attribution (cause) plus one concrete, dated next action. See CLAUDE.md.
 *
 * The cause taxonomy deliberately contains only controllable, specific causes.
 * Stable/global attributions ("I'm bad at math") are NOT representable here —
 * that is a product-safety rule encoded as a constraint, not a suggestion.
 * Pure domain; no framework imports.
 */

/**
 * Controllable, specific causes a student can act on. The final "other" option
 * opens a free-text box for the student's own specific reason — which tends to
 * be MORE specific and controllable than a preset, exactly what supports
 * adaptive attribution (Weiner). Stable/global blame is still unrepresentable.
 */
export const CAUSES = [
  { id: "misread", label: "I misread or misunderstood the question" },
  { id: "unreviewed", label: "I hadn't reviewed this specific topic" },
  { id: "rushed", label: "I rushed and didn't check my work" },
  { id: "guessed", label: "I guessed instead of reasoning it through" },
  { id: "mixed-up", label: "I mixed this up with something similar" },
  { id: "other", label: "Something else — I'll say what" },
] as const;

export type CauseId = (typeof CAUSES)[number]["id"];

export interface Reflection {
  readonly causeId: CauseId;
  /** The student's own specific reason, required when causeId is "other". */
  readonly otherText?: string;
  readonly nextAction: string;
}

export interface ReflectionInput {
  readonly causeId: string;
  readonly otherText?: string;
  readonly nextAction: string;
}

const CAUSE_IDS: ReadonlySet<string> = new Set(CAUSES.map((c) => c.id));

/** Build a Reflection, enforcing the constrained-attribution invariants. */
export function createReflection(input: ReflectionInput): Reflection {
  if (!CAUSE_IDS.has(input.causeId)) {
    throw new RangeError(
      `Cause must be one of the controllable, specific causes; got "${input.causeId}".`,
    );
  }

  let otherText: string | undefined;
  if (input.causeId === "other") {
    otherText = (input.otherText ?? "").trim();
    if (otherText.length < 3) {
      throw new RangeError("Tell us the specific reason in a few words.");
    }
  }

  const nextAction = input.nextAction.trim();
  if (nextAction.length < 3) {
    throw new RangeError("Next action must be a concrete step.");
  }

  return { causeId: input.causeId as CauseId, otherText, nextAction };
}

/** Human-readable label for a cause id. */
export function causeLabel(causeId: CauseId): string {
  const found = CAUSES.find((c) => c.id === causeId);
  if (!found) {
    throw new RangeError(`Unknown causeId: ${causeId}`);
  }
  return found.label;
}
