/**
 * Reflection — the feed-forward output of a cycle: a CONTROLLABLE + SPECIFIC
 * attribution (cause) plus one concrete, dated next action. See CLAUDE.md.
 *
 * The cause taxonomy deliberately contains only controllable, specific causes.
 * Stable/global attributions ("I'm bad at math") are NOT representable here —
 * that is a product-safety rule encoded as a constraint, not a suggestion.
 * Pure domain; no framework imports.
 */

/** Controllable, specific causes a student can actually act on. */
export const CAUSES = [
  { id: "misread", label: "I misread or misunderstood the question" },
  { id: "unreviewed", label: "I hadn't reviewed this specific topic" },
  { id: "rushed", label: "I rushed and didn't check my work" },
  { id: "guessed", label: "I guessed instead of reasoning it through" },
  { id: "mixed-up", label: "I mixed this up with something similar" },
] as const;

export type CauseId = (typeof CAUSES)[number]["id"];

export interface Reflection {
  readonly causeId: CauseId;
  readonly nextAction: string;
  /** ISO calendar date (YYYY-MM-DD) the action is committed to. */
  readonly dueDate: string;
}

export interface ReflectionInput {
  readonly causeId: string;
  readonly nextAction: string;
  readonly dueDate: string;
}

const CAUSE_IDS: ReadonlySet<string> = new Set(CAUSES.map((c) => c.id));
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** Build a Reflection, enforcing the constrained-attribution invariants. */
export function createReflection(input: ReflectionInput): Reflection {
  if (!CAUSE_IDS.has(input.causeId)) {
    throw new RangeError(
      `Cause must be one of the controllable, specific causes; got "${input.causeId}".`,
    );
  }

  const nextAction = input.nextAction.trim();
  if (nextAction.length < 3) {
    throw new RangeError("Next action must be a concrete step.");
  }

  if (!ISO_DATE.test(input.dueDate) || Number.isNaN(Date.parse(input.dueDate))) {
    throw new RangeError("Due date must be a valid calendar date (YYYY-MM-DD).");
  }

  return { causeId: input.causeId as CauseId, nextAction, dueDate: input.dueDate };
}

/** Human-readable label for a cause id. */
export function causeLabel(causeId: CauseId): string {
  const found = CAUSES.find((c) => c.id === causeId);
  if (!found) {
    throw new RangeError(`Unknown causeId: ${causeId}`);
  }
  return found.label;
}
