/**
 * Design tokens — the single source of truth.
 * Mirrored 1:1 into the Tailwind `@theme` block in `src/app/globals.css`.
 * Change one, change the other. (See CLAUDE.md → Design tokens.)
 *
 * Rules baked in here:
 *  - warm accent is for affective/human moments ONLY (<=5% of surface, never text color)
 *  - accuracy is NEVER green=good / red=bad: alignment uses ink-tint, gaps use warm.
 */
export const tokens = {
  color: {
    white: "#FFFFFF",
    paper: "#F6F8FA",
    ink: "#1B3A5B",
    inkTint: "#3E6187",
    inkWash: "#E8EEF4",
    inkBlack: "#0F1B26",
    secondary: "#536878",
    warm: "#E0A06A",
  },
  /** Accuracy semantics — deliberately not green/red. */
  state: {
    aligned: "#3E6187", // ink-tint
    gap: "#E0A06A", // warm
  },
  radius: {
    control: "6px",
    card: "12px",
  },
  font: {
    sans: "Inter, ui-sans-serif, system-ui, sans-serif",
  },
} as const;

export type Tokens = typeof tokens;
