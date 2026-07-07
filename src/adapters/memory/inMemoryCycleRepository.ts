/**
 * In-memory implementation of the CycleRepository port. Process-lifetime storage
 * — the current infrastructure. Adapters may be impure (ids, timestamps).
 */

import type { CycleRepository } from "@/domain/ports/cycleRepository";
import type { Cycle, NewCycle } from "@/domain/cycle";

export class InMemoryCycleRepository implements CycleRepository {
  private readonly cycles: Cycle[] = [];
  private seq = 0;

  save(cycle: NewCycle): Promise<Cycle> {
    const stored: Cycle = {
      ...cycle,
      id: `cycle_${(this.seq += 1)}`,
      createdAt: new Date().toISOString(),
    };
    this.cycles.push(stored);
    return Promise.resolve(stored);
  }

  list(): Promise<readonly Cycle[]> {
    return Promise.resolve([...this.cycles]);
  }
}
