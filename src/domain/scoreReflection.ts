/**
 * ScoreReflection — the closing metacognitive reflection: a short series of
 * open-ended questions asking a student to make sense of the score they got.
 * This is Zimmerman's self-reflection phase (self-evaluation → causal
 * attribution → adaptive self-reaction). Pure domain.
 *
 * QUESTION DESIGN (evidence-based, tuned for high-school engagement):
 *  - Krosnick & Presser (2010): simple wording, ONE idea per item, and concrete
 *    specificity reduce satisficing/skipping and raise answer quality.
 *  - Kluger & DeNisi (1996): feedback/attention on the SELF harms performance —
 *    so every prompt points at the WORK and the PROCESS, never "are you smart".
 *  - Weiner (1985): steer attributions toward specific, controllable, unstable
 *    causes; the free-text room and "what you did" framing do this.
 *  - Flanagan (1954) critical-incident technique: episodic "walk me through the
 *    moment" prompts pull far richer recall than abstract "why in general".
 *  - Gollwitzer & Sheeran (2006): implementation intentions ("when X, I'll Y")
 *    beat vague goals for follow-through — so the forward question is if-then.
 *  - Deci & Ryan (SDT): autonomy-supportive, non-evaluative, normalized wording
 *    raises willingness to answer honestly.
 *  - Deliberately NOT growth-mindset framing (per CLAUDE.md): grounded in
 *    attribution + SDT instead.
 *
 * Prompts use {predicted} / {actual} placeholders, filled in the UI so the
 * question is anchored to the student's own numbers (concrete > abstract).
 */

export interface ScoreQuestion {
  readonly id: string;
  readonly prompt: string;
  /** A short example that models a good answer — scaffolds the blank page. */
  readonly helper: string;
  /** True if the prompt only makes sense when the student missed something. */
  readonly needsMiss: boolean;
}

export const SCORE_QUESTIONS: readonly ScoreQuestion[] = [
  {
    id: "gap",
    prompt:
      "You expected about {predicted}% and got {actual}%. Thinking about how you worked — not whether you're “good at this” — what best explains that gap?",
    helper:
      "e.g. “They looked easy so I answered fast and didn’t re-read the tricky one.”",
    needsMiss: false,
  },
  {
    id: "moment",
    prompt:
      "Take the question you were most sure about but still missed. What was going through your head the moment you answered it?",
    helper: "Walk me through it like you're telling a friend.",
    needsMiss: true,
  },
  {
    id: "plan",
    prompt:
      "Next time a question feels this easy, what's the one thing you'll do before you lock in your answer?",
    helper: "Finish the sentence: “When a question looks easy, I'll ______.”",
    needsMiss: false,
  },
];

export interface ScoreReflection {
  readonly answers: Readonly<Record<string, string>>;
}

/** Assemble a ScoreReflection: trim answers, keep only known question ids. */
export function createScoreReflection(
  answers: Readonly<Record<string, string>>,
): ScoreReflection {
  const known = new Set(SCORE_QUESTIONS.map((q) => q.id));
  const cleaned: Record<string, string> = {};
  for (const [id, value] of Object.entries(answers)) {
    if (known.has(id)) {
      const trimmed = value.trim();
      if (trimmed.length > 0) cleaned[id] = trimmed;
    }
  }
  return { answers: cleaned };
}

/** The questions to show, given whether the student missed anything. */
export function questionsFor(hadMiss: boolean): readonly ScoreQuestion[] {
  return SCORE_QUESTIONS.filter((q) => hadMiss || !q.needsMiss);
}
