/**
 * Transfer probe — a fresh item served after a student feels they "get it",
 * to test real transfer vs. the fluency illusion. Pure domain.
 */

export interface TransferProbe {
  readonly id: string;
  readonly statement: string;
  readonly isTrue: boolean;
}

export interface ProbeResult {
  /** True when the fresh item was answered correctly — evidence of real transfer. */
  readonly transferred: boolean;
}

export function scoreProbe(probe: TransferProbe, answer: boolean): ProbeResult {
  return { transferred: answer === probe.isTrue };
}
