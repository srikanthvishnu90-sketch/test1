/**
 * Composition root — wires ports to concrete adapters. The rest of the app
 * depends only on the port types, never on the concrete class. Swap the adapter
 * here (e.g. to a Postgres-backed one) without touching any consumer.
 */

import type { CycleRepository } from "@/domain/ports/cycleRepository";
import { InMemoryCycleRepository } from "@/adapters/memory/inMemoryCycleRepository";

export const cycleRepository: CycleRepository = new InMemoryCycleRepository();
