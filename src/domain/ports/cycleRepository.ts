/**
 * CycleRepository — the persistence PORT for completed cycles. The domain and
 * application depend on this interface; concrete storage lives in adapters.
 */

import type { Cycle, NewCycle } from "../cycle";

export interface CycleRepository {
  /** Persist a completed cycle, returning it with an assigned id + timestamp. */
  save(cycle: NewCycle): Promise<Cycle>;
  /** All persisted cycles, oldest first. */
  list(): Promise<readonly Cycle[]>;
}
