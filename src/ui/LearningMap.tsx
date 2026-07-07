import { locateOnMap, CALIBRATION_STAGES } from "@/domain/learningMap";

/**
 * The learning map a student locates themselves on. Highlights the current stage
 * with ink (chrome), never green/red. Located from recent evidence, so it moves
 * as cycles accumulate — trajectory over any single judgment.
 */

interface Props {
  readonly recentBriers: readonly number[];
}

export default function LearningMap({ recentBriers }: Props): React.ReactElement {
  const current = locateOnMap(recentBriers);

  return (
    <section className="mt-4 rounded-card border border-ink-wash bg-white p-5">
      <h2 className="text-sm font-semibold text-ink">Where you are on calibration</h2>
      <p className="mt-1 text-xs text-secondary">
        Locate yourself — this moves as your cycles add up.
      </p>

      <ol className="mt-4 flex flex-col gap-2 sm:flex-row">
        {CALIBRATION_STAGES.map((stage) => {
          const here = stage.id === current.id;
          return (
            <li
              key={stage.id}
              aria-current={here ? "step" : undefined}
              className="flex-1 rounded-control border p-3"
              style={{
                borderColor: here ? "var(--color-ink)" : "var(--color-ink-wash)",
                backgroundColor: here ? "var(--color-ink-wash)" : "transparent",
              }}
            >
              <p
                className="text-xs font-semibold"
                style={{
                  color: here ? "var(--color-ink)" : "var(--color-secondary)",
                }}
              >
                {stage.label}
                {here && " · you're here"}
              </p>
              <p className="mt-1 text-xs text-secondary">{stage.description}</p>
            </li>
          );
        })}
      </ol>
    </section>
  );
}
